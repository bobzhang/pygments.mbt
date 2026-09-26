///|
/// Arguments captured by a callback factory (e.g. the token type passed to
/// YAML's `save_indent(Text, start=True)`).
pub(all) enum CallbackArg {
  Str(String)
  Tok(@token.TokenType)
  Bool(Bool)
  Int(Int)
} derive(Debug)

///|
/// A hand-written callback (Python: a callable token action).
pub type CallbackFn = (Ctx, @regex.Match, Array[CallbackArg]) -> Unit raise

///|
/// Target of a `using(...)` action.
pub(all) enum UsingTarget {
  /// `using(this)`: the current lexer class
  This
  /// `using(OtherLexer)`: a constructor
  Other((Options) -> Lexer raise)
}

///|
/// What to do with a match (Python: the second element of a rule).
pub(all) enum Action {
  /// `None`: emit nothing
  Nop
  /// a plain token type
  Emit(@token.TokenType)
  /// `bygroups(...)`: one action per group
  ByGroups(Array[Action])
  /// `using(target, state=..., **kwargs)`
  Using(UsingTarget, Array[String]?, Array[(String, String)])
  /// a bespoke callback by qualified name, with captured arguments
  Call(String, Array[CallbackArg])
}

///|
/// One state-stack operation of a transition.
pub(all) enum StateOp {
  /// push a named state
  Push(String)
  /// `#pop` (never pops the last state)
  Pop
  /// `#push`: push the current state again
  Dup
} derive(Debug)

///|
/// A lexing rule: regex, action and optional transition.
pub struct Rule {
  pattern : String
  flags : Int
  action : Action
  transition : Array[StateOp]?
  priv mut regex : @regex.Regex?
  priv mut ops : FixedArray[Int]
}

///|
/// Creates a rule. `transition` is `None` when the rule does not change
/// the state stack.
pub fn Rule::new(
  pattern : String,
  flags : Int,
  action : Action,
  transition : Array[StateOp]?,
) -> Rule {
  { pattern, flags, action, transition, regex: None, ops: [], }
}

///|
fn Rule::compiled(self : Rule) -> @regex.Regex raise {
  match self.regex {
    Some(r) => r
    None => {
      let r = @regex.compile(self.pattern, flags=self.flags)
      self.regex = Some(r)
      r
    }
  }
}

///|
/// The processed token definitions of a `RegexLexer` class: named states,
/// each an ordered list of rules (includes, inheritance, `words()` and
/// `combined()` already resolved by the exporter).
pub struct RegexDef {
  name : String
  state_names : Array[String]
  priv state_index : Map[String, Int]
  priv states : Array[Array[Rule]]
  /// `ExtendedRegexLexer` semantics (callbacks own `ctx.pos`)
  extended : Bool
}

///|
/// Builds a definition from rules and, per state, the indices of its rules.
pub fn RegexDef::new(
  name : String,
  state_names : Array[String],
  rules : Array[Rule],
  states : Array[Array[Int]],
  extended? : Bool = false,
) -> RegexDef {
  let state_index : Map[String, Int] = Map([])
  for i, n in state_names {
    state_index[n] = i
  }
  let resolved = states.map(idxs => idxs.map(i => rules[i]))
  for r in rules {
    match r.transition {
      None => ()
      Some(ops) =>
        r.ops = FixedArray::from_array(
          ops.map(op => {
            match op {
              Push(n) =>
                match state_index.get(n) {
                  Some(i) => i
                  None => abort("\{name}: unknown state \{n}")
                }
              Pop => -1
              Dup => -2
            }
          }),
        )
    }
  }
  { name, state_names, state_index, states: resolved, extended, }
}

///|
/// Index of the state `name`.
pub fn RegexDef::state(self : RegexDef, name : String) -> Int {
  match self.state_index.get(name) {
    Some(i) => i
    None => abort("\{self.name}: unknown state \{name}")
  }
}

///|
/// Errors raised while lexing.
pub suberror LexError {
  MissingCallback(String)
  UnknownState(String)
} derive(Debug)

///|
/// The lexing context handed to callbacks (Python's `LexerContext` plus the
/// output buffer). Callbacks may move `pos` and `end`.
pub(all) struct Ctx {
  lexer : Lexer
  def : RegexDef
  text : String
  mut pos : Int
  mut end : Int
  stack : Array[Int]
  out : Array[Token]
  callbacks : Map[String, CallbackFn]
}

///|
/// Appends a token to the output.
pub fn Ctx::emit(
  self : Ctx,
  index : Int,
  ttype : @token.TokenType,
  value : String,
) -> Unit {
  self.out.push({ index, ttype, value, })
}

///|
/// Pushes the state `name`.
pub fn Ctx::push_state(self : Ctx, name : String) -> Unit raise {
  match self.def.state_index.get(name) {
    Some(i) => self.stack.push(i)
    None => raise UnknownState(name)
  }
}

///|
/// Pops a state, keeping at least one on the stack.
pub fn Ctx::pop_state(self : Ctx) -> Unit {
  if self.stack.length() > 1 {
    ignore(self.stack.pop())
  }
}

///|
/// Name of the current (top) state.
pub fn Ctx::top_state(self : Ctx) -> String {
  self.def.state_names[self.stack[self.stack.length() - 1]]
}

///|
/// Names of the states on the stack, bottom first.
pub fn Ctx::state_stack(self : Ctx) -> Array[String] {
  self.stack.map(i => self.def.state_names[i])
}

///|
/// Replaces the state stack.
pub fn Ctx::set_state_stack(self : Ctx, names : Array[String]) -> Unit raise {
  self.stack.clear()
  for n in names {
    self.push_state(n)
  }
}

///|
/// Whether this context follows `ExtendedRegexLexer` semantics.
pub fn Ctx::is_extended(self : Ctx) -> Bool {
  self.def.extended
}

///|
/// Applies `action` to `m` (Python: calling a token action).
pub fn Ctx::apply(self : Ctx, action : Action, m : @regex.Match) -> Unit raise {
  match action {
    Nop => ()
    Emit(t) => self.emit(m.start(), t, m.matched())
    ByGroups(actions) => {
      for i, a in actions {
        let g = i + 1
        match a {
          Nop => ()
          Emit(t) =>
            match m.group(g) {
              Some(data) if data != "" => self.emit(m.start(group=g), t, data)
              _ => ()
            }
          other =>
            if m.start(group=g) >= 0 {
              if self.def.extended {
                self.pos = m.start(group=g)
              }
              self.apply(
                other,
                @regex.Match::from_span(
                  m.text,
                  m.start(group=g),
                  m.end(group=g),
                ),
              )
            }
        }
      }
      if self.def.extended {
        self.pos = m.end()
      }
    }
    Using(target, stack, kwargs) => {
      let lx = match target {
        This =>
          if kwargs.is_empty() {
            self.lexer
          } else {
            self.lexer.recreate(merge_options(self.lexer.options, kwargs))
          }
        Other(create) => create(merge_options(self.lexer.options, kwargs))
      }
      let s = m.start()
      let toks = lx.get_tokens_unprocessed(
        m.matched(),
        stack=stack.unwrap_or(["root"]),
      )
      for t in toks {
        self.out.push({ index: t.index + s, ttype: t.ttype, value: t.value, })
      }
      if self.def.extended {
        self.pos = m.end()
      }
    }
    Call(name, args) =>
      match self.callbacks.get(name) {
        Some(f) => f(self, m, args)
        None => raise MissingCallback(name)
      }
  }
}

///|
/// Lexes `text` with `lexer` and appends the tokens shifted by `offset`
/// (Python: `for i, t, v in lx.get_tokens_unprocessed(...): yield i + offset, t, v`).
pub fn Ctx::emit_lexed(
  self : Ctx,
  lexer : Lexer,
  text : String,
  offset : Int,
  stack? : Array[String] = ["root"],
) -> Unit raise {
  for t in lexer.get_tokens_unprocessed(text, stack~) {
    self.out.push({ index: t.index + offset, ttype: t.ttype, value: t.value, })
  }
}

///|
fn merge_options(base : Options, extra : Array[(String, String)]) -> Options {
  let m : Map[String, String] = Map([])
  for k, v in base {
    m[k] = v
  }
  for kv in extra {
    m[kv.0] = kv.1
  }
  m
}

///|
fn Ctx::transition(self : Ctx, ops : FixedArray[Int]) -> Unit {
  for op in ops {
    if op >= 0 {
      self.stack.push(op)
    } else if op == -1 {
      if self.stack.length() > 1 {
        ignore(self.stack.pop())
      }
    } else {
      self.stack.push(self.stack[self.stack.length() - 1])
    }
  }
}

///|
fn code_point_width(text : String, pos : Int) -> Int {
  let c = text.unsafe_get(pos).to_int()
  if c >= 0xD800 &&
    c <= 0xDBFF &&
    pos + 1 < text.length() &&
    text.unsafe_get(pos + 1).to_int() >= 0xDC00 &&
    text.unsafe_get(pos + 1).to_int() <= 0xDFFF {
    2
  } else {
    1
  }
}

///|
/// Runs a `RegexLexer` (or `ExtendedRegexLexer`) over `text`, starting with
/// the state stack `stack`. `callbacks` resolves `Action::Call` names.
pub fn run_regex(
  lexer : Lexer,
  def : RegexDef,
  text : String,
  stack : Array[String],
  callbacks? : Map[String, CallbackFn] = {},
) -> Array[Token] raise {
  let ctx : Ctx = {
    lexer,
    def,
    text,
    pos: 0,
    end: text.length(),
    stack: [],
    out: [],
    callbacks,
  }
  ctx.set_state_stack(stack)
  if def.extended {
    run_extended(ctx)
  } else {
    run_simple(ctx)
  }
  ctx.out
}

///|
/// Runs a `RegexLexer` or `ExtendedRegexLexer` over an existing context
/// (Python: `get_tokens_unprocessed(text, context)`).
pub fn run_context(ctx : Ctx) -> Unit raise {
  if ctx.def.extended {
    run_extended(ctx)
  } else {
    run_simple(ctx)
  }
}

///|
/// Creates a context for `run_context`, e.g. to pre-set the position or stack.
pub fn Ctx::new(
  lexer : Lexer,
  def : RegexDef,
  text : String,
  callbacks? : Map[String, CallbackFn] = {},
  pos? : Int = 0,
  end? : Int,
  stack? : Array[String] = ["root"],
) -> Ctx raise {
  let ctx : Ctx = {
    lexer,
    def,
    text,
    pos,
    end: end.unwrap_or(text.length()),
    stack: [],
    out: [],
    callbacks,
  }
  ctx.set_state_stack(stack)
  ctx
}

///|
fn run_simple(ctx : Ctx) -> Unit raise {
  let def = ctx.def
  let text = ctx.text
  let budget = budget()
  let root = def.state("root")
  let mut rules = def.states[ctx.stack[ctx.stack.length() - 1]]
  while true {
    let mut matched = false
    for rule in rules {
      match rule.compiled().match_at(text, ctx.pos, budget~) {
        None => ()
        Some(m) => {
          match rule.action {
            Nop => ()
            Emit(t) => ctx.emit(ctx.pos, t, m.matched())
            a => ctx.apply(a, m)
          }
          ctx.pos = m.end()
          if rule.transition is Some(_) {
            ctx.transition(rule.ops)
            rules = def.states[ctx.stack[ctx.stack.length() - 1]]
          }
          matched = true
          break
        }
      }
    }
    if !matched {
      if ctx.pos >= text.length() {
        break
      }
      if text.unsafe_get(ctx.pos) == '\n' {
        ctx.stack.clear()
        ctx.stack.push(root)
        rules = def.states[root]
        ctx.emit(ctx.pos, @token.whitespace, "\n")
        ctx.pos += 1
        continue
      }
      let w = code_point_width(text, ctx.pos)
      ctx.emit(
        ctx.pos,
        @token.error,
        text.unsafe_substring(start=ctx.pos, end=ctx.pos + w),
      )
      ctx.pos += w
    }
  }
}

///|
fn run_extended(ctx : Ctx) -> Unit raise {
  let def = ctx.def
  let text = ctx.text
  let budget = budget()
  let root = def.state("root")
  let mut rules = def.states[ctx.stack[ctx.stack.length() - 1]]
  while true {
    let mut matched = false
    for rule in rules {
      match rule.compiled().match_at(text, ctx.pos, endpos=ctx.end, budget~) {
        None => ()
        Some(m) => {
          match rule.action {
            Nop => ()
            Emit(t) => {
              ctx.emit(ctx.pos, t, m.matched())
              ctx.pos = m.end()
            }
            a => {
              ctx.apply(a, m)
              if rule.transition is None {
                rules = def.states[ctx.stack[ctx.stack.length() - 1]]
              }
            }
          }
          if rule.transition is Some(_) {
            ctx.transition(rule.ops)
            rules = def.states[ctx.stack[ctx.stack.length() - 1]]
          }
          matched = true
          break
        }
      }
    }
    if !matched {
      if ctx.pos >= ctx.end {
        break
      }
      if text.unsafe_get(ctx.pos) == '\n' {
        ctx.stack.clear()
        ctx.stack.push(root)
        rules = def.states[root]
        ctx.emit(ctx.pos, @token.text, "\n")
        ctx.pos += 1
        continue
      }
      let w = code_point_width(text, ctx.pos)
      ctx.emit(
        ctx.pos,
        @token.error,
        text.unsafe_substring(start=ctx.pos, end=ctx.pos + w),
      )
      ctx.pos += w
    }
  }
}
