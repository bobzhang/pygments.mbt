// Hand-written parts of pygments/lexers/perl.py.
// pydata: perl6_brackets = L.perl.Perl6Lexer.PERL6_BRACKETS

///|
let perl_decl_re : @regex.Regex = @lexer.re("(?:my|our)\\s+[$@%(]")

///|
fn perl_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "perl") {
    return 1.0
  }
  let mut result = 0.0
  if @lexer.search(perl_decl_re, text) {
    result += 0.9
  }
  if text.contains(":=") {
    // := is not valid Perl, but it appears in unicon
    result /= 2.0
  }
  result
}

///|
let perl6_to_adverb_re : @regex.Regex = @lexer.re(":to\\b")

///|
/// `Perl6Lexer.brackets_callback(token_class)`: finds the closing delimiter
/// (respecting nesting for mirrored brackets, and `:to` heredocs).
fn perl6_brackets_callback(
  ctx : @lexer.Ctx,
  m : @regex.Match,
  token_class : @token.TokenType,
) -> Unit raise {
  let opening_chars = m.named("delimiter").unwrap_or("")
  let n_chars = opening_chars.length()
  let delim_start = m.start(group=m.name_index("delimiter").unwrap())
  let adverbs = m.named("adverbs")
  let text = ctx.text
  let first = opening_chars.unsafe_substring(start=0, end=1)
  let mut end_pos = match perl6_brackets.get(first) {
    None => pystr_find(text, opening_chars, delim_start + n_chars)
    Some(closer) => {
      let closing_chars = closer.repeat(n_chars)
      let mut nesting_level = 1
      let mut search_pos = delim_start
      let mut next_close_pos = 0
      while nesting_level > 0 {
        let next_open_pos = pystr_find(
          text,
          opening_chars,
          search_pos + n_chars,
        )
        next_close_pos = pystr_find(text, closing_chars, search_pos + n_chars)
        if next_close_pos == -1 {
          next_close_pos = text.length()
          nesting_level = 0
        } else if next_open_pos != -1 && next_open_pos < next_close_pos {
          nesting_level += 1
          search_pos = next_open_pos
        } else {
          nesting_level -= 1
          search_pos = next_close_pos
        }
      }
      next_close_pos
    }
  }
  if end_pos < 0 {
    end_pos = text.length()
  }
  match adverbs {
    Some(adv) if @lexer.search(perl6_to_adverb_re, adv) => {
      let terminator = @lexer.py_slice(text, delim_start + n_chars, end_pos)
      let heredoc_re = @regex.compile(
        "^\\s*" + pystr_re_escape(terminator) + "\\s*$",
        flags=@regex.MULTILINE,
      )
      match heredoc_re.search(pystr_from(text, end_pos)) {
        Some(eh) => end_pos += eh.end()
        None => end_pos = text.length()
      }
    }
    _ => ()
  }
  let stop = end_pos + n_chars
  ctx.emit(m.start(), token_class, @lexer.py_slice(text, m.start(), stop))
  ctx.pos = if stop > text.length() { text.length() } else { stop }
}

///|
/// Callbacks of `Perl6Lexer`; the brace nesting level inside `token`
/// blocks is per-run state (Python: `context.perl6_token_nesting_level`).
fn perl6_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let nesting_level = Ref(0)
  let below_token = (ctx : @lexer.Ctx) => {
    let stack = ctx.state_stack()
    stack.length() > 2 && stack[stack.length() - 2] == "token"
  }
  {
    "Perl6Lexer.brackets_callback": (ctx, m, args) => {
      guard args is [Tok(token_class), ..] else {
        fail("brackets_callback: missing token class")
      }
      perl6_brackets_callback(ctx, m, token_class)
    },
    "Perl6Lexer.opening_brace_callback": (ctx, m, _) => {
      ctx.emit(m.start(), @token.text, m.matched())
      ctx.pos = m.end()
      if below_token(ctx) {
        nesting_level.val += 1
      }
    },
    "Perl6Lexer.closing_brace_callback": (ctx, m, _) => {
      ctx.emit(m.start(), @token.text, m.matched())
      ctx.pos = m.end()
      if below_token(ctx) {
        nesting_level.val -= 1
        if nesting_level.val == 0 {
          ctx.pop_state()
        }
      }
    },
    "Perl6Lexer.embedded_perl6_callback": (ctx, m, _) => {
      nesting_level.val = 1
      ctx.emit(m.start(), @token.text, m.matched())
      ctx.pos = m.end()
      ctx.push_state("root")
    },
  }
}

///|
/// `Perl6Lexer.__init__` only records the `encoding` option.
fn perl6_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    perl6_lexer_def.force(),
    text,
    stack,
    callbacks=perl6_lexer_callbacks(lx),
  )
}

///|
let perl6_pod_end_re : @regex.Regex = @lexer.re("^=(?:end|cut)")

///|
let perl6_pod_start_re : @regex.Regex = @lexer.re("^=\\w+")

///|
let perl6_decl_re : @regex.Regex = @lexer.re(
  "(?:my|our|has)\\s+(?:['\\w:-]+\\s+)?[$@%&(]",
)

///|
let perl6_comment_re : @regex.Regex = @lexer.re("#.*")

///|
let perl6_blank_re : @regex.Regex = @lexer.re("^\\s*$")

///|
let perl6_v6_re : @regex.Regex = @lexer.re(
  "^\\s*(?:use\\s+)?v6(?:\\.\\d(?:\\.\\d)?)?;",
)

///|
let perl6_class_decl_re : @regex.Regex = @lexer.re(
  "^\\s*(?:(?P<scope>my|our)\\s+)?(?:module|class|role|enum|grammar)",
)

///|
fn perl6_lexer_analyse(text : String) -> Double {
  let lines = []
  let mut in_pod = false
  for line in pystr_splitlines(text) {
    if @lexer.matches(perl6_pod_end_re, line) {
      in_pod = false
    } else if @lexer.matches(perl6_pod_start_re, line) {
      in_pod = true
    } else if !in_pod {
      lines.push(line)
    }
  }
  let text = lines.join("\n")
  if @lexer.shebang_matches(text, "perl6|rakudo|niecza|pugs") {
    return 1.0
  }
  let mut saw_perl_decl = false
  let mut rating = 0.0
  if @lexer.search(perl6_decl_re, text) {
    rating = 0.8
    saw_perl_decl = true
  }
  for line in lines {
    let line = perl6_comment_re.replace_all(line, _ => "") catch { _ => line }
    if @lexer.matches(perl6_blank_re, line) {
      continue
    }
    if @lexer.matches(perl6_v6_re, line) {
      return 1.0
    }
    match (perl6_class_decl_re.match_at(line, 0) catch { _ => None }) {
      Some(class_decl) => {
        if saw_perl_decl || class_decl.named("scope") is Some(_) {
          return 1.0
        }
        rating = 0.05
        continue
      }
      None => ()
    }
    break
  }
  if text.contains(":=") {
    rating /= 2.0
  }
  rating
}
