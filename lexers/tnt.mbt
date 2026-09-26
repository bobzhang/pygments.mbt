// Hand-written parts of pygments/lexers/tnt.py.
// pydata: tnt_rules_pattern = L.tnt.TNTLexer.RULES.pattern

///|
let tnt_rules_re : @regex.Regex = @lexer.re(tnt_rules_pattern)

///|
let tnt_linenos_re : @regex.Regex = @lexer.re(
  "(?:[0-9]+)(?:(?:, ?|,? and )(?:[0-9]+))*",
)

///|
let tnt_comment_re : @regex.Regex = @lexer.re("\\[[^\\n\\]]+\\]")

///|
/// Python's `AssertionError` and `IndexError` as raised by `TNTLexer`.
priv suberror TntError {
  Assertion
  Index
}

///|
/// The state of one `TNTLexer.get_tokens_unprocessed` run. Positions are
/// code point indices (as in Python); `off` maps them to UTF-16 offsets.
priv struct TntLexer {
  text : String
  chars : Array[Char]
  off : Array[Int]
  cp_of : Array[Int]
  cur : Array[(Int, @token.TokenType, String)]
  mut start : Int
  mut end : Int
  mut orig : Int?
}

///|
fn TntLexer::new(text : String) -> TntLexer {
  let chars = text.to_array()
  let off = Array::make(chars.length() + 1, 0)
  let cp_of = Array::make(text.length() + 1, 0)
  let mut u = 0
  for i, c in chars {
    off[i] = u
    cp_of[u] = i
    u += if c.to_int() > 0xFFFF { 2 } else { 1 }
  }
  off[chars.length()] = u
  cp_of[u] = chars.length()
  { text, chars, off, cp_of, cur: [], start: 0, end: 0, orig: None, }
}

///|
/// `text[i]`, raising `IndexError` past the end.
fn TntLexer::at(self : TntLexer, i : Int) -> Char raise TntError {
  if i < 0 || i >= self.chars.length() {
    raise Index
  }
  self.chars[i]
}

///|
/// `text[a:b]` (clamped as Python slicing).
fn TntLexer::sl(self : TntLexer, a : Int, b : Int) -> String {
  let n = self.chars.length()
  let a = if a > n { n } else { a }
  let b = if b > n { n } else { b }
  if a >= b {
    ""
  } else {
    String::from_array(self.chars[a:b])
  }
}

///|
fn TntLexer::add(
  self : TntLexer,
  start : Int,
  t : @token.TokenType,
  v : String,
) -> Unit {
  self.cur.push((start, t, v))
}

///|
fn tnt_is_whitespace(c : Char) -> Bool {
  c is ('\t' | ' ' | '\u{0b}' | '\n')
}

///|
fn tnt_is_variable(c : Char) -> Bool {
  c is ('a' | 'b' | 'c' | 'd' | 'e')
}

///|
fn tnt_is_number(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn TntLexer::whitespace(
  self : TntLexer,
  start : Int,
  required? : Bool = false,
) -> Int raise TntError {
  let mut end = start
  while end < self.chars.length() && tnt_is_whitespace(self.chars[end]) {
    end += 1
  }
  if required && end == start {
    raise Assertion
  }
  if end != start {
    self.add(start, @token.text, self.sl(start, end))
  }
  end
}

///|
fn TntLexer::variable(self : TntLexer, start : Int) -> Int raise TntError {
  if !tnt_is_variable(self.at(start)) {
    raise Assertion
  }
  let mut end = start + 1
  while self.at(end) is ('\'' | '′') {
    end += 1
  }
  self.add(start, @token.name_variable, self.sl(start, end))
  end
}

///|
fn TntLexer::term(self : TntLexer, start : Int) -> Int raise TntError {
  let c = self.at(start)
  if c == 'S' {
    let mut end = start + 1
    while self.at(end) == 'S' {
      end += 1
    }
    self.add(start, @token.number_integer, self.sl(start, end))
    return self.term(end)
  }
  if c == '0' {
    self.add(start, @token.number_integer, "0")
    return start + 1
  }
  if tnt_is_variable(c) {
    return self.variable(start)
  }
  if c == '(' {
    self.add(start, @token.punctuation, "(")
    let start = self.term(start + 1)
    let op = self.at(start)
    if !(op is ('+' | '.' | '⋅' | '*')) {
      raise Assertion
    }
    self.add(start, @token.operator, op.to_string())
    let start = self.term(start + 1)
    if self.at(start) != ')' {
      raise Assertion
    }
    self.add(start, @token.punctuation, ")")
    return start + 1
  }
  raise Assertion
}

///|
fn TntLexer::formula(self : TntLexer, start : Int) -> Int raise TntError {
  let c = self.at(start)
  if c is ('~' | '!') {
    let mut end = start + 1
    while self.at(end) is ('~' | '!') {
      end += 1
    }
    self.add(start, @token.operator, self.sl(start, end))
    return self.formula(end)
  }
  if c is ('A' | 'E' | '∀' | '∃') {
    self.add(start, @token.keyword_declaration, c.to_string())
    let start = self.variable(start + 1)
    if self.at(start) != ':' {
      raise Assertion
    }
    self.add(start, @token.punctuation, ":")
    return self.formula(start + 1)
  }
  if c == '<' {
    self.add(start, @token.punctuation, "<")
    let start = self.formula(start + 1)
    let op = self.at(start)
    if !(op
      is ('⊃' | '→' | ']' | '&' | '∧' | '^' | '|' | '∨' | 'V' | 'v')) {
      raise Assertion
    }
    self.add(start, @token.operator, op.to_string())
    let start = self.formula(start + 1)
    if self.at(start) != '>' {
      raise Assertion
    }
    self.add(start, @token.punctuation, ">")
    return start + 1
  }
  let start = self.term(start)
  if self.at(start) != '=' {
    raise Assertion
  }
  self.add(start, @token.operator, "=")
  self.term(start + 1)
}

///|
fn TntLexer::rule(self : TntLexer, start : Int) -> Int raise TntError {
  let m = tnt_rules_re.match_at(self.text, self.off[start]) catch { _ => None }
  guard m is Some(m) else { raise Assertion }
  let mend = self.cp_of[m.end()]
  // sorted(match.regs[1:]): the first participating group
  let mut group : (Int, Int)? = None
  for g in 1..<=m.group_count() {
    if m.start(group=g) >= 0 {
      let span = (self.cp_of[m.start(group=g)], self.cp_of[m.end(group=g)])
      match group {
        Some(best) if best <= span => ()
        _ => group = Some(span)
      }
    }
  }
  match group {
    Some((g0, g1)) => {
      self.add(start, @token.keyword, self.sl(start, g0))
      self.add(g0, @token.number_integer, self.sl(g0, g1))
      if g1 != mend {
        self.add(g1, @token.keyword, self.sl(g1, mend))
      }
    }
    None => self.add(start, @token.keyword, self.sl(start, mend))
  }
  mend
}

///|
fn TntLexer::lineno(self : TntLexer, start : Int) -> Int raise TntError {
  let mut end = start
  while !tnt_is_number(self.at(end)) {
    end += 1
  }
  self.add(start, @token.punctuation, self.at(start).to_string())
  self.add(start + 1, @token.text, self.sl(start + 1, end))
  let m = tnt_linenos_re.match_at(self.text, self.off[end]) catch { _ => None }
  guard m is Some(m) else { raise Assertion }
  let mend = self.cp_of[m.end()]
  if self.at(mend) != ')' {
    raise Assertion
  }
  self.add(end, @token.number_integer, m.matched())
  self.add(mend, @token.punctuation, ")")
  mend + 1
}

///|
fn TntLexer::error_till_line_end(self : TntLexer, start : Int) -> Int {
  let mut end = start
  while end < self.chars.length() && self.chars[end] != '\n' {
    end += 1
  }
  if end != start {
    self.add(start, @token.error, self.sl(start, end))
  }
  self.whitespace(end) catch {
    _ => end
  }
}

///|
/// One iteration of the main loop of `TNTLexer.get_tokens_unprocessed`
/// (`return` is Python's `continue`). An `IndexError` escapes to `run`.
fn TntLexer::step(self : TntLexer) -> Unit raise TntError {
  while tnt_is_number(self.at(self.end)) {
    self.end += 1
  }
  if self.end != self.start {
    self.add(self.start, @token.number_integer, self.sl(self.start, self.end))
    self.orig = Some(self.cur.length())
    let ws = self.whitespace(self.end, required=true) catch {
      Assertion => {
        self.recover(self.end)
        return
      }
      e => raise e
    }
    self.start = ws
    self.end = ws
  }
  let comment = tnt_comment_re.match_at(self.text, self.off[self.start]) catch {
    _ => None
  }
  if comment is Some(m) {
    let mend = self.cp_of[m.end()]
    self.add(self.start, @token.comment, self.sl(self.start, mend))
    self.skip_line(mend)
    return
  }
  let c = self.at(self.start)
  if c is ('[' | ']') {
    self.add(self.start, @token.keyword, c.to_string())
    self.start += 1
    self.end += 1
  } else {
    self.orig = Some(self.cur.length())
    let f = self.formula(self.start) catch {
      Assertion => {
        self.truncate()
        while !tnt_is_whitespace(self.at(self.end)) {
          self.end += 1
        }
        self.add(self.start, @token.error, self.sl(self.start, self.end))
        self.end
      }
      e => raise e
    }
    self.start = f
    self.end = f
  }
  self.orig = Some(self.cur.length())
  let ws = self.whitespace(self.end, required=true) catch {
    Assertion => {
      self.recover(self.start)
      return
    }
    e => raise e
  }
  self.start = ws
  self.end = ws
  self.orig = Some(self.cur.length())
  let r = self.rule(ws) catch {
    Assertion => {
      self.recover(ws)
      return
    }
    e => raise e
  }
  self.start = self.whitespace(r)
  self.end = self.start
  if self.at(self.start) == '(' {
    self.orig = Some(self.cur.length())
    let l = self.lineno(self.start) catch {
      Assertion => {
        self.recover(self.start)
        return
      }
      e => raise e
    }
    self.start = self.whitespace(l)
    self.end = self.start
  }
}

///|
/// `del self.cur[orig:]`.
fn TntLexer::truncate(self : TntLexer) -> Unit {
  if self.orig is Some(o) {
    while self.cur.length() > o {
      ignore(self.cur.pop())
    }
  }
}

///|
/// `start = end = self.error_till_line_end(pos)`.
fn TntLexer::skip_line(self : TntLexer, pos : Int) -> Unit {
  self.start = self.error_till_line_end(pos)
  self.end = self.start
}

///|
/// `del self.cur[orig:]; start = end = self.error_till_line_end(pos)`.
fn TntLexer::recover(self : TntLexer, pos : Int) -> Unit {
  self.truncate()
  self.skip_line(pos)
}

///|
/// `TNTLexer.get_tokens_unprocessed`, including its exception-driven error
/// recovery (`orig` is a function-scoped variable in Python).
fn TntLexer::run(self : TntLexer) -> Unit {
  let n = self.chars.length()
  self.start = self.whitespace(0) catch { _ => 0 }
  self.end = self.start
  while self.start <= self.end && self.end < n {
    self.step() catch {
      _ => {
        // IndexError
        self.truncate()
        ignore(self.error_till_line_end(self.start))
      }
    }
  }
}

///|
#warnings("-unused_error_type")
fn tnt_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let st = TntLexer::new(text)
  st.run()
  st.cur.map(t => { index: st.off[t.0], ttype: t.1, value: t.2, })
}
