///|
/// `re.IGNORECASE`
pub const IGNORECASE : Int = 2

///|
/// `re.LOCALE` (accepted, treated as no-op)
pub const LOCALE : Int = 4

///|
/// `re.MULTILINE`
pub const MULTILINE : Int = 8

///|
/// `re.DOTALL`
pub const DOTALL : Int = 16

///|
/// `re.UNICODE` (the default for text patterns)
pub const UNICODE : Int = 32

///|
/// `re.VERBOSE`
pub const VERBOSE : Int = 64

///|
/// `re.ASCII`
pub const ASCII : Int = 256

///|
/// Errors raised by the regex engine.
pub suberror RegexError {
  /// The pattern is not valid Python `re` syntax (or uses an unsupported
  /// construct).
  Syntax(pattern~ : String, pos~ : Int, message~ : String)
  /// The step budget of a match was exhausted (catastrophic backtracking).
  BudgetExceeded(pattern~ : String)
} derive(Debug)

///|
pub extend RegexError with Debug::{to_repr}

///|
priv enum AssertKind {
  Bol // ^ without MULTILINE: start of string
  BolM // ^ with MULTILINE
  Eol // $ without MULTILINE
  EolM // $ with MULTILINE
  StrStart // \A
  StrEnd // \Z
  WordB(Bool) // \b ; Bool = ASCII
  NotWordB(Bool) // \B
}

///|
priv enum Greed {
  Greedy
  Lazy
  Possessive
} derive(Eq)

///|
priv enum Node {
  Empty
  Char(Int)
  Set(CharSet)
  Seq(Array[Node])
  Alt(Array[Node])
  Group(Int, Node) // capture index (>= 1)
  Repeat(Node, Int, Int, Greed) // min, max (-1 = unbounded)
  Assert(AssertKind)
  Backref(Int, Int) // group, case folding (0: none, 1: unicode, 2: ascii)
  Look(Node, Bool, Bool) // behind?, negated?
  Atomic(Node)
  Cond(Int, Node, Node)
}

///|
priv struct Parser {
  src : String
  mut pos : Int
  mut flags : Int
  mut ngroups : Int
  names : Map[String, Int]
  open_groups : Array[Int]
}

///|
fn Parser::fail(self : Parser, msg : String) -> RegexError {
  Syntax(pattern=self.src, pos=self.pos, message=msg)
}

///|
fn Parser::eof(self : Parser) -> Bool {
  self.pos >= self.src.length()
}

///|
fn Parser::peek(self : Parser) -> Int {
  if self.pos < self.src.length() {
    self.src[self.pos].to_int()
  } else {
    -1
  }
}

///|
fn Parser::peek_at(self : Parser, off : Int) -> Int {
  let p = self.pos + off
  if p < self.src.length() {
    self.src[p].to_int()
  } else {
    -1
  }
}

///|
fn Parser::accept(self : Parser, c : Int) -> Bool {
  if self.peek() == c {
    self.pos += 1
    true
  } else {
    false
  }
}

///|
/// Reads one code point (combining surrogate pairs).
fn Parser::next_cp(self : Parser) -> Int {
  let c = self.src[self.pos].to_int()
  self.pos += 1
  if c >= 0xD800 && c <= 0xDBFF && self.pos < self.src.length() {
    let d = self.src[self.pos].to_int()
    if d >= 0xDC00 && d <= 0xDFFF {
      self.pos += 1
      return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00)
    }
  }
  c
}

///|
fn is_digit(c : Int) -> Bool {
  c >= 48 && c <= 57
}

///|
fn is_octal(c : Int) -> Bool {
  c >= 48 && c <= 55
}

///|
fn hex_value(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 97 && c <= 102 {
    c - 87
  } else if c >= 65 && c <= 70 {
    c - 55
  } else {
    -1
  }
}

///|
fn is_ascii_letter(c : Int) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

///|
fn flag_of_letter(c : Int) -> Int {
  match c {
    'a' => ASCII
    'i' => IGNORECASE
    'L' => LOCALE
    'm' => MULTILINE
    's' => DOTALL
    'u' => UNICODE
    'x' => VERBOSE
    _ => 0
  }
}

///|
fn parse_pattern(
  src : String,
  flags : Int,
) -> (Node, Int, Map[String, Int], Int) raise RegexError {
  let p : Parser = {
    src,
    pos: 0,
    flags,
    ngroups: 0,
    names: {},
    open_groups: [],
  }
  p.parse_global_flags()
  let node = p.parse_alt()
  if !p.eof() {
    if p.peek() == ')' {
      raise p.fail("unbalanced parenthesis")
    }
    raise p.fail("unexpected trailing input")
  }
  (node, p.ngroups, p.names, p.flags)
}

///|
/// Global inline flags such as `(?i)` must appear at the start of the pattern
/// (Python >= 3.11).
fn Parser::parse_global_flags(self : Parser) -> Unit {
  while true {
    if (self.flags & VERBOSE) != 0 {
      self.skip_verbose()
    }
    guard self.peek() == '(' && self.peek_at(1) == '?' else { return }
    let save = self.pos
    self.pos += 2
    let mut add = 0
    while !self.eof() && flag_of_letter(self.peek()) != 0 {
      add = add | flag_of_letter(self.peek())
      self.pos += 1
    }
    if add != 0 && self.accept(')') {
      self.flags = self.flags | add
    } else {
      self.pos = save
      return
    }
  }
}

///|
fn Parser::skip_verbose(self : Parser) -> Unit {
  while !self.eof() {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == 11 || c == 12 {
      self.pos += 1
    } else if c == '#' {
      while !self.eof() && self.peek() != '\n' {
        self.pos += 1
      }
    } else {
      break
    }
  }
}

///|
fn Parser::parse_alt(self : Parser) -> Node raise RegexError {
  let branches = [self.parse_seq()]
  while self.accept('|') {
    branches.push(self.parse_seq())
  }
  if branches.length() == 1 {
    branches[0]
  } else {
    Alt(branches)
  }
}

///|
fn Parser::parse_seq(self : Parser) -> Node raise RegexError {
  let items : Array[Node] = []
  let mut last_quantified = false
  while true {
    if (self.flags & VERBOSE) != 0 {
      self.skip_verbose()
    }
    if self.eof() {
      break
    }
    let c = self.peek()
    if c == '|' || c == ')' {
      break
    }
    if c == '*' || c == '+' || c == '?' || c == '{' {
      if self.parse_quantifier(items, last_quantified) {
        last_quantified = true
        continue
      }
      // `{` that is not a valid quantifier is a literal
    }
    match self.parse_atom() {
      Some(atom) => {
        items.push(atom)
        last_quantified = false
      }
      None => ()
    }
  }
  match items.length() {
    0 => Empty
    1 => items[0]
    _ => Seq(items)
  }
}

///|
/// Tries to parse a quantifier applying to the last item. Returns false when
/// the input is a `{` that must be read as a literal.
fn Parser::parse_quantifier(
  self : Parser,
  items : Array[Node],
  last_quantified : Bool,
) -> Bool raise RegexError {
  let start = self.pos
  let c = self.peek()
  let (min, max) = if c == '*' {
    self.pos += 1
    (0, -1)
  } else if c == '+' {
    self.pos += 1
    (1, -1)
  } else if c == '?' {
    self.pos += 1
    (0, 1)
  } else {
    // '{'
    self.pos += 1
    if self.peek() == '}' {
      self.pos = start
      return false
    }
    let lo_start = self.pos
    while is_digit(self.peek()) {
      self.pos += 1
    }
    let lo_s = self.src.unsafe_substring(start=lo_start, end=self.pos)
    let mut hi_s = lo_s
    let mut has_comma = false
    if self.accept(',') {
      has_comma = true
      let hi_start = self.pos
      while is_digit(self.peek()) {
        self.pos += 1
      }
      hi_s = self.src.unsafe_substring(start=hi_start, end=self.pos)
    }
    if !self.accept('}') {
      self.pos = start
      return false
    }
    let min = if lo_s == "" { 0 } else { self.parse_dec(lo_s) }
    let max = if hi_s == "" {
      if has_comma {
        -1
      } else {
        0
      }
    } else {
      self.parse_dec(hi_s)
    }
    if max >= 0 && max < min {
      raise self.fail("min repeat greater than max repeat")
    }
    (min, max)
  }
  let n = items.length()
  if n == 0 {
    raise self.fail("nothing to repeat")
  }
  let last = items[n - 1]
  if last_quantified {
    raise self.fail("multiple repeat")
  }
  if last is (Assert(_) | Empty) {
    raise self.fail("nothing to repeat")
  }
  let greed = if self.accept('?') {
    Lazy
  } else if self.accept('+') {
    Possessive
  } else {
    Greedy
  }
  items[n - 1] = Repeat(last, min, max, greed)
  true
}

///|
fn Parser::parse_dec(self : Parser, s : String) -> Int raise RegexError {
  let mut v = 0
  for c in s {
    v = v * 10 + (c.to_int() - 48)
    if v > MAX_REPEAT {
      raise self.fail("the repetition number is too large")
    }
  }
  v
}

///|
/// Largest supported repeat count (CPython's limit is `MAXREPEAT - 1`).
const MAX_REPEAT : Int = 0x7fffffff / 16

///|
fn Parser::dot(self : Parser) -> Node {
  if (self.flags & DOTALL) != 0 {
    Set(CharSet::from_ranges([(0, MAX_CP)]))
  } else {
    Set(CharSet::from_ranges([(0, 9), (11, MAX_CP)]))
  }
}

///|
/// A literal code point, honouring IGNORECASE.
fn Parser::literal(self : Parser, c : Int) -> Node {
  if (self.flags & IGNORECASE) == 0 {
    return Char(c)
  }
  if (self.flags & ASCII) != 0 {
    if is_ascii_letter(c) {
      let l = ascii_lower(c)
      Set(CharSet::from_ranges([(l, l), (l - 32, l - 32)]))
    } else {
      Char(c)
    }
  } else {
    let eq = case_equivalents(c)
    if eq.length() == 1 {
      Char(c)
    } else {
      Set(CharSet::from_ranges(eq.map(x => (x, x))))
    }
  }
}

///|
fn Parser::category(self : Parser, c : Int) -> CharSet {
  let ascii = (self.flags & ASCII) != 0
  match c {
    'd' => if ascii { ascii_digit } else { unicode_digit }
    'D' => (if ascii { ascii_digit } else { unicode_digit }).complement()
    's' => if ascii { ascii_space } else { unicode_space }
    'S' => (if ascii { ascii_space } else { unicode_space }).complement()
    'w' => if ascii { ascii_word } else { unicode_word }
    _ => (if ascii { ascii_word } else { unicode_word }).complement()
  }
}

///|
fn Parser::parse_atom(self : Parser) -> Node? raise RegexError {
  let c = self.peek()
  match c {
    '(' => {
      self.pos += 1
      self.parse_group()
    }
    '[' => {
      self.pos += 1
      Some(self.parse_class())
    }
    '.' => {
      self.pos += 1
      Some(self.dot())
    }
    '^' => {
      self.pos += 1
      Some(Assert(if (self.flags & MULTILINE) != 0 { BolM } else { Bol }))
    }
    '$' => {
      self.pos += 1
      Some(Assert(if (self.flags & MULTILINE) != 0 { EolM } else { Eol }))
    }
    '\\' => {
      self.pos += 1
      Some(self.parse_escape())
    }
    _ => Some(self.literal(self.next_cp()))
  }
}

///|
fn Parser::read_hex(self : Parser, n : Int) -> Int raise RegexError {
  let mut v = 0
  for _ in 0..<n {
    let h = hex_value(self.peek())
    if h < 0 {
      raise self.fail("incomplete escape")
    }
    v = v * 16 + h
    self.pos += 1
  }
  v
}

///|
/// Escapes common to both contexts; returns -1 if `c` is not one of them.
fn Parser::simple_escape(self : Parser, c : Int) -> Int raise RegexError {
  match c {
    'a' => 7
    'f' => 12
    'n' => 10
    'r' => 13
    't' => 9
    'v' => 11
    'x' => self.read_hex(2)
    'u' => self.read_hex(4)
    'U' => {
      let v = self.read_hex(8)
      if v > MAX_CP {
        raise self.fail("bad escape")
      }
      v
    }
    'N' => raise self.fail("\\N{...} escapes are not supported")
    _ => -1
  }
}

///|
fn Parser::parse_escape(self : Parser) -> Node raise RegexError {
  if self.eof() {
    raise self.fail("bad escape (end of pattern)")
  }
  let c = self.next_cp()
  match c {
    'A' => Assert(StrStart)
    'Z' => Assert(StrEnd)
    'b' => Assert(WordB((self.flags & ASCII) != 0))
    'B' => Assert(NotWordB((self.flags & ASCII) != 0))
    'd' | 'D' | 's' | 'S' | 'w' | 'W' => Set(self.category(c))
    '0' => {
      let mut v = 0
      let mut k = 0
      while k < 2 && is_octal(self.peek()) {
        v = v * 8 + (self.peek() - 48)
        self.pos += 1
        k += 1
      }
      self.literal(v)
    }
    '1'..='9' => {
      let d1 = c
      if is_digit(self.peek()) {
        let d2 = self.peek()
        self.pos += 1
        if is_octal(d1) && is_octal(d2) && is_octal(self.peek()) {
          let d3 = self.peek()
          self.pos += 1
          let v = (d1 - 48) * 64 + (d2 - 48) * 8 + (d3 - 48)
          if v > 0o377 {
            raise self.fail("octal escape value outside of range 0-0o377")
          }
          return self.literal(v)
        }
        self.backref((d1 - 48) * 10 + (d2 - 48))
      } else {
        self.backref(d1 - 48)
      }
    }
    _ => {
      let v = self.simple_escape(c)
      if v >= 0 {
        self.literal(v)
      } else if is_ascii_letter(c) {
        raise self.fail("bad escape \\" + c.unsafe_to_char().to_string())
      } else {
        self.literal(c)
      }
    }
  }
}

///|
fn Parser::backref(self : Parser, g : Int) -> Node raise RegexError {
  if g > self.ngroups {
    raise self.fail("invalid group reference \{g}")
  }
  if self.open_groups.contains(g) {
    raise self.fail("cannot refer to an open group")
  }
  let fold = if (self.flags & IGNORECASE) == 0 {
    0
  } else if (self.flags & ASCII) != 0 {
    2
  } else {
    1
  }
  Backref(g, fold)
}

///|
/// Parses a class escape. Returns `Ok(cp)` for a single character or
/// `Err(set)` for a category.
fn Parser::class_escape(self : Parser) -> Result[Int, CharSet] raise RegexError {
  if self.eof() {
    raise self.fail("bad escape (end of pattern)")
  }
  let c = self.next_cp()
  match c {
    'd' | 'D' | 's' | 'S' | 'w' | 'W' => Err(self.category(c))
    'b' => Ok(8)
    '0'..='7' => {
      let mut v = c - 48
      let mut k = 0
      while k < 2 && is_octal(self.peek()) {
        v = v * 8 + (self.peek() - 48)
        self.pos += 1
        k += 1
      }
      if v > 0o377 {
        raise self.fail("octal escape value outside of range 0-0o377")
      }
      Ok(v)
    }
    '8' | '9' => raise self.fail("bad escape")
    _ => {
      let v = self.simple_escape(c)
      if v >= 0 {
        Ok(v)
      } else if is_ascii_letter(c) {
        raise self.fail("bad escape \\" + c.unsafe_to_char().to_string())
      } else {
        Ok(c)
      }
    }
  }
}

///|
fn Parser::parse_class(self : Parser) -> Node raise RegexError {
  let negate = self.accept('^')
  let start = self.pos
  let pairs : Array[(Int, Int)] = []
  while true {
    if self.eof() {
      raise self.fail("unterminated character set")
    }
    if self.peek() == ']' && self.pos != start {
      self.pos += 1
      break
    }
    let item1 = if self.peek() == '\\' {
      self.pos += 1
      self.class_escape()
    } else {
      Ok(self.next_cp())
    }
    if self.peek() == '-' {
      self.pos += 1
      if self.eof() {
        raise self.fail("unterminated character set")
      }
      if self.peek() == ']' {
        self.pos += 1
        add_item(pairs, item1)
        pairs.push(('-', '-'))
        break
      }
      let item2 = if self.peek() == '\\' {
        self.pos += 1
        self.class_escape()
      } else {
        Ok(self.next_cp())
      }
      match (item1, item2) {
        (Ok(lo), Ok(hi)) => {
          if hi < lo {
            raise self.fail("bad character range")
          }
          pairs.push((lo, hi))
        }
        _ => raise self.fail("bad character range")
      }
    } else {
      add_item(pairs, item1)
    }
  }
  let closed = if (self.flags & IGNORECASE) != 0 {
    case_close(pairs, (self.flags & ASCII) != 0)
  } else {
    pairs
  }
  let set = CharSet::from_ranges(closed)
  Set(if negate { set.complement() } else { set })
}

///|
fn add_item(pairs : Array[(Int, Int)], item : Result[Int, CharSet]) -> Unit {
  match item {
    Ok(c) => pairs.push((c, c))
    Err(set) => pairs.append(set.to_pairs())
  }
}

///|
fn Parser::read_name(self : Parser, term : Int) -> String raise RegexError {
  let start = self.pos
  while !self.eof() && self.peek() != term {
    self.pos += 1
  }
  if self.eof() {
    raise self.fail("missing terminator for group name")
  }
  let name = self.src.unsafe_substring(start~, end=self.pos)
  self.pos += 1
  if name == "" {
    raise self.fail("missing group name")
  }
  name
}

///|
fn Parser::expect_close(self : Parser) -> Unit raise RegexError {
  if !self.accept(')') {
    raise self.fail("missing ), unterminated subpattern")
  }
}

///|
/// Parses a sub-expression with a temporary flag set.
fn Parser::parse_sub(self : Parser, flags : Int) -> Node raise RegexError {
  let saved = self.flags
  self.flags = flags
  let node = self.parse_alt()
  self.flags = saved
  node
}

///|
fn Parser::parse_group(self : Parser) -> Node? raise RegexError {
  if !self.accept('?') {
    return Some(self.capture_group(None, self.flags))
  }
  let c = self.peek()
  match c {
    'P' => {
      self.pos += 1
      if self.accept('<') {
        let name = self.read_name('>')
        Some(self.capture_group(Some(name), self.flags))
      } else if self.accept('=') {
        let name = self.read_name(')')
        match self.names.get(name) {
          Some(g) => Some(self.backref(g))
          None => raise self.fail("unknown group name '\{name}'")
        }
      } else {
        raise self.fail("unknown extension ?P")
      }
    }
    ':' => {
      self.pos += 1
      let node = self.parse_sub(self.flags)
      self.expect_close()
      Some(node)
    }
    '#' => {
      while !self.eof() && self.peek() != ')' {
        self.pos += 1
      }
      self.expect_close()
      None
    }
    '=' | '!' => {
      self.pos += 1
      let node = self.parse_sub(self.flags)
      self.expect_close()
      Some(Look(node, false, c == '!'))
    }
    '<' => {
      self.pos += 1
      let d = self.peek()
      if d != '=' && d != '!' {
        raise self.fail("unknown extension ?<")
      }
      self.pos += 1
      let node = self.parse_sub(self.flags)
      self.expect_close()
      match fixed_width(node) {
        Some(_) => ()
        None => raise self.fail("look-behind requires fixed-width pattern")
      }
      Some(Look(node, true, d == '!'))
    }
    '>' => {
      self.pos += 1
      let node = self.parse_sub(self.flags)
      self.expect_close()
      Some(Atomic(node))
    }
    '(' => {
      self.pos += 1
      let name = self.read_name(')')
      let g = match self.names.get(name) {
        Some(g) => g
        None => {
          let mut v = 0
          for ch in name {
            let d = ch.to_int()
            if !is_digit(d) {
              raise self.fail("bad character in group name '\{name}'")
            }
            v = v * 10 + (d - 48)
          }
          if v == 0 || v > 1000 {
            raise self.fail("bad group number")
          }
          v
        }
      }
      let yes = self.parse_seq_alt_limited()
      let no = if self.accept('|') {
        let n = self.parse_seq_alt_limited()
        if self.peek() == '|' {
          raise self.fail("conditional backref with more than two branches")
        }
        n
      } else {
        Empty
      }
      self.expect_close()
      Some(Cond(g, yes, no))
    }
    _ => {
      // scoped or global inline flags
      let mut add = 0
      let mut del = 0
      while !self.eof() && flag_of_letter(self.peek()) != 0 {
        add = add | flag_of_letter(self.peek())
        self.pos += 1
      }
      if self.accept('-') {
        while !self.eof() && flag_of_letter(self.peek()) != 0 {
          del = del | flag_of_letter(self.peek())
          self.pos += 1
        }
        if del == 0 {
          raise self.fail("missing flag")
        }
      }
      if self.accept(')') {
        raise self.fail("global flags not at the start of the expression")
      }
      if !self.accept(':') {
        raise self.fail("unknown extension")
      }
      let mut scoped = (self.flags | add) & del.lnot()
      if (add & UNICODE) != 0 {
        scoped = scoped & ASCII.lnot()
      }
      if (add & ASCII) != 0 {
        scoped = scoped & UNICODE.lnot()
      }
      let node = self.parse_sub(scoped)
      self.expect_close()
      Some(node)
    }
  }
}

///|
/// One branch of a conditional group (a sequence, no top-level `|`).
fn Parser::parse_seq_alt_limited(self : Parser) -> Node raise RegexError {
  self.parse_seq()
}

///|
fn Parser::capture_group(
  self : Parser,
  name : String?,
  flags : Int,
) -> Node raise RegexError {
  self.ngroups += 1
  let g = self.ngroups
  match name {
    Some(n) => {
      if self.names.contains(n) {
        raise self.fail("redefinition of group name '\{n}'")
      }
      self.names[n] = g
    }
    None => ()
  }
  self.open_groups.push(g)
  let node = self.parse_sub(flags)
  self.expect_close()
  ignore(self.open_groups.pop())
  Group(g, node)
}

///|
/// The width (in code points) of `node` if it is fixed.
fn fixed_width(node : Node) -> Int? {
  match node {
    Empty | Assert(_) | Look(_, _, _) => Some(0)
    Char(_) | Set(_) => Some(1)
    Seq(items) => {
      let mut w = 0
      for it in items {
        match fixed_width(it) {
          Some(x) => w += x
          None => return None
        }
      }
      Some(w)
    }
    Alt(branches) => {
      let mut w = -1
      for b in branches {
        match fixed_width(b) {
          Some(x) => if w < 0 { w = x } else if w != x { return None }
          None => return None
        }
      }
      Some(if w < 0 { 0 } else { w })
    }
    Group(_, n) | Atomic(n) => fixed_width(n)
    Repeat(n, min, max, _) =>
      if min == max {
        match fixed_width(n) {
          Some(x) => Some(x * min)
          None => None
        }
      } else {
        None
      }
    Backref(_, _) => None
    Cond(_, a, b) =>
      match (fixed_width(a), fixed_width(b)) {
        (Some(x), Some(y)) if x == y => Some(x)
        _ => None
      }
  }
}
