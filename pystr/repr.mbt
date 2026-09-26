///|
let hex_digits : String = "0123456789abcdef"

///|
/// `n` as `width` lowercase hex digits.
fn hex(n : Int, width : Int) -> String {
  let buf = StringBuilder()
  for i = width - 1; i >= 0; i = i - 1 {
    buf.write_char(hex_digits.unsafe_get((n >> (4 * i)) & 15).unsafe_to_char())
  }
  buf.to_string()
}

///|
fn write_escaped(buf : StringBuilder, cp : Int) -> Unit {
  if cp <= 0xff {
    buf.write_string("\\x")
    buf.write_string(hex(cp, 2))
  } else if cp <= 0xffff {
    buf.write_string("\\u")
    buf.write_string(hex(cp, 4))
  } else {
    buf.write_string("\\U")
    buf.write_string(hex(cp, 8))
  }
}

///|
fn repr_impl(s : String, ascii_only : Bool) -> String {
  let quote = if s.contains("'") && !s.contains("\"") { '"' } else { '\'' }
  let buf = StringBuilder()
  buf.write_char(quote)
  for c in s {
    let cp = c.to_int()
    if c == quote || c == '\\' {
      buf.write_char('\\')
      buf.write_char(c)
    } else if c == '\t' {
      buf.write_string("\\t")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if cp < 0x20 || cp == 0x7f {
      write_escaped(buf, cp)
    } else if cp < 0x7f {
      buf.write_char(c)
    } else if !ascii_only && is_printable(c) {
      buf.write_char(c)
    } else {
      write_escaped(buf, cp)
    }
  }
  buf.write_char(quote)
  buf.to_string()
}

///|
/// Python's `repr` of a string.
///
/// ```mbt check
/// test {
///   inspect(@pystr.repr("it's\n"), content="\"it's\\n\"")
///   inspect(@pystr.repr("a\u{85}é"), content="'a\\x85é'")
/// }
/// ```
pub fn repr(s : String) -> String {
  repr_impl(s, false)
}

///|
/// Python's `ascii` of a string (`repr` with every non-ASCII character
/// escaped), as produced by `b"%r" % s`.
///
/// ```mbt check
/// test {
///   inspect(@pystr.ascii("é😀"), content="'\\xe9\\U0001f600'")
/// }
/// ```
pub fn ascii(s : String) -> String {
  repr_impl(s, true)
}
