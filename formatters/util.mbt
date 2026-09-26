///|
/// Python's `_get_ttype_class` (html) / `_get_ttype_name` (latex): the short
/// name of the nearest standard ancestor followed by `-<component>` for the
/// remaining components (`Name.Builtin.Magic` gives `nb-Magic`).
pub fn ttype_class(t : @token.TokenType) -> String {
  let names = @token.standard_names()
  let mut suffix = ""
  let mut cur = t
  while true {
    match names.get(cur) {
      Some(short) => return short + suffix
      None => ()
    }
    suffix = "-" + cur.last() + suffix
    match cur.parent() {
      Some(p) => cur = p
      None => break
    }
  }
  suffix
}

///|
/// Whether `t` is one of Python's `STANDARD_TYPES`.
fn is_standard(t : @token.TokenType) -> Bool {
  @token.standard_names().contains(t)
}

///|
/// The path components of `t` below the root (Python's tuple value of the
/// token type: `Token.Name.Builtin` is `('Name', 'Builtin')`).
fn ttype_tuple(t : @token.TokenType) -> Array[String] {
  let out = []
  let mut cur = t
  while true {
    match cur.parent() {
      Some(p) => {
        out.push(cur.last())
        cur = p
      }
      None => break
    }
  }
  out.rev_in_place()
  out
}

///|
/// Python's `str(ttype)` minus the leading `Token.` (`''` for `Token`).
fn ttype_repr_tail(t : @token.TokenType) -> String {
  ttype_tuple(t).join(".")
}

///|
/// Python string ordering (by code point; code units are equivalent for
/// the ASCII names compared here).
fn py_str_compare(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a.unsafe_get(i).to_int() - b.unsafe_get(i).to_int()
    if c != 0 {
      return c
    }
  }
  a.length() - b.length()
}

///|
/// Python tuple ordering of token types.
fn ttype_compare(a : @token.TokenType, b : @token.TokenType) -> Int {
  let x = ttype_tuple(a)
  let y = ttype_tuple(b)
  let n = if x.length() < y.length() { x.length() } else { y.length() }
  for i in 0..<n {
    let c = py_str_compare(x[i], y[i])
    if c != 0 {
      return c
    }
  }
  x.length() - y.length()
}

///|
/// Python's `html.webify`: a CSS color from a style color.
pub fn webify(color : String) -> String {
  if color == "transparent" ||
    color.has_prefix("calc") ||
    color.has_prefix("var") {
    return color
  }
  let color = @pystr.upper(color)
  let c = color.to_array()
  if c.length() == 6 && c[0] == c[1] && c[2] == c[3] && c[4] == c[5] {
    "#\{c[0]}\{c[2]}\{c[4]}"
  } else {
    "#\{color}"
  }
}

///|
/// Python's `int(s)` for decimal strings (surrounding whitespace, an
/// optional sign and single underscores between digits are accepted).
fn py_int(s : String) -> Int? {
  let t = s.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
  let chars = t.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if chars[0] == '+' || chars[0] == '-' {
    neg = chars[0] == '-'
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut n = 0
  let mut prev_digit = false
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
      prev_digit = true
    } else if c == '_' && prev_digit && i + 1 < chars.length() {
      prev_digit = false
    } else {
      return None
    }
    i += 1
  }
  if !prev_digit {
    return None
  }
  Some(if neg { -n } else { n })
}

///|
/// Python's `a % b` (result has the sign of `b`); raises Python's
/// `ZeroDivisionError` for `b == 0`.
fn py_mod(a : Int, b : Int) -> Int raise FormatterError {
  if b == 0 {
    raise FormatterError("ZeroDivisionError: integer modulo by zero")
  }
  let r = a % b
  if r != 0 && (r < 0) != (b < 0) {
    r + b
  } else {
    r
  }
}

///|
/// Python's `abs(get_int_opt(options, name, default))`.
fn abs_int_opt(
  options : @lexer.Options,
  name : String,
  default : Int,
) -> Int raise {
  let v = @lexer.get_int_opt(options, name, default)
  if v < 0 {
    -v
  } else {
    v
  }
}

///|
/// Python truthiness of an option given as a string (`options.get(name,
/// False)` used as a Boolean): present and non-empty.
fn truthy_opt(options : @lexer.Options, name : String) -> Bool {
  match options.get(name) {
    Some(v) => v != ""
    None => false
  }
}

///|
/// Python's `int(hex, 16)` for up to 8 hex digits (`None` if invalid).
fn parse_hex(s : String) -> Int? {
  let t = s.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
  if t.length() == 0 {
    return None
  }
  let mut n = 0
  let mut prev_digit = false
  let chars = t.to_array()
  for i, c in chars {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else if c == '_' && prev_digit && i + 1 < chars.length() {
      prev_digit = false
      continue
    } else {
      return None
    }
    n = n * 16 + d
    prev_digit = true
  }
  if prev_digit {
    Some(n)
  } else {
    None
  }
}
