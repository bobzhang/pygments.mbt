///|
/// Python's `s.split(sep)` for a non-empty separator: always at least one
/// part (`"".split("\n") == [""]`).
///
/// ```mbt check
/// test {
///   inspect(@pystr.split("a\nb\n", "\n").length(), content="3")
///   inspect(@pystr.split("", "\n").length(), content="1")
/// }
/// ```
pub fn split(s : String, sep : String) -> Array[String] {
  let out = []
  let mut start = 0
  let n = sep.length()
  while true {
    match s.view(start_offset=start).find(sep) {
      Some(i) => {
        out.push(s.unsafe_substring(start~, end=start + i))
        start = start + i + n
      }
      None => {
        out.push(s.unsafe_substring(start~, end=s.length()))
        break
      }
    }
  }
  out
}

///|
/// Whether `c` is a line boundary for Python's `str.splitlines`.
pub fn is_line_break(c : Char) -> Bool {
  match c {
    '\n' | '\r' | '\u{0b}' | '\u{0c}' | '\u{1c}' | '\u{1d}' | '\u{1e}' => true
    '\u{85}' | '\u{2028}' | '\u{2029}' => true
    _ => false
  }
}

///|
/// Python's `str.splitlines(keepends)`.
///
/// ```mbt check
/// test {
///   inspect(
///     @pystr.splitlines("a\r\nb\u{0c}c", keepends=true).length(),
///     content="3",
///   )
///   inspect(@pystr.splitlines("", keepends=true).length(), content="0")
/// }
/// ```
pub fn splitlines(s : String, keepends? : Bool = false) -> Array[String] {
  let out = []
  let n = s.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    let cu = s.unsafe_get(i).to_int()
    // all line breaks are in the BMP, so code units suffice
    if cu < 0xd800 && is_line_break(cu.unsafe_to_char()) {
      let mut eol = i + 1
      if cu == 0x0d && eol < n && s.unsafe_get(eol).to_int() == 0x0a {
        eol += 1
      }
      out.push(s.unsafe_substring(start~, end=if keepends { eol } else { i }))
      start = eol
      i = eol
    } else {
      i += 1
    }
  }
  if start < n {
    out.push(s.unsafe_substring(start~, end=n))
  }
  out
}

///|
/// Python's `str.expandtabs(tabsize)`: the column (in code points) resets
/// after `\n` and `\r`.
///
/// ```mbt check
/// test {
///   inspect(@pystr.expandtabs("a\tb\n\tc", tabsize=4), content="a   b\n    c")
/// }
/// ```
pub fn expandtabs(s : String, tabsize? : Int = 8) -> String {
  let buf = StringBuilder()
  let mut col = 0
  for c in s {
    if c == '\t' {
      if tabsize > 0 {
        let pad = tabsize - col % tabsize
        for _ in 0..<pad {
          buf.write_char(' ')
        }
        col += pad
      }
    } else {
      buf.write_char(c)
      col += 1
      if c == '\n' || c == '\r' {
        col = 0
      }
    }
  }
  buf.to_string()
}

///|
/// Python's `html.escape(s, quote)`.
///
/// ```mbt check
/// test {
///   inspect(
///     @pystr.html_escape("<a href='x'>&\"</a>"),
///     content="&lt;a href=&#x27;x&#x27;&gt;&amp;&quot;&lt;/a&gt;",
///   )
/// }
/// ```
pub fn html_escape(s : String, quote? : Bool = true) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' if quote => buf.write_string("&quot;")
      '\'' if quote => buf.write_string("&#x27;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// The number of code points in `s` (Python's `len`).
pub fn py_len(s : String) -> Int {
  s.char_length()
}

///|
/// Python's `s[start:end]` with code point indices (negative indices count
/// from the end; out-of-range indices are clamped).
///
/// ```mbt check
/// test {
///   inspect(@pystr.slice("héllo", 1, end=3), content="él")
///   inspect(@pystr.slice("héllo", -2), content="lo")
/// }
/// ```
pub fn slice(s : String, start : Int, end? : Int) -> String {
  let n = s.char_length()
  fn norm(i : Int) -> Int {
    let i = if i < 0 { i + n } else { i }
    if i < 0 {
      0
    } else if i > n {
      n
    } else {
      i
    }
  }

  let a = norm(start)
  let b = match end {
    Some(e) => norm(e)
    None => n
  }
  if a >= b {
    return ""
  }
  let off = (i : Int) => {
    if i == n {
      s.length()
    } else {
      s.offset_of_nth_char(i).unwrap_or(s.length())
    }
  }
  s.unsafe_substring(start=off(a), end=off(b))
}

///|
/// `s` without trailing `\n` characters (Python's `s.rstrip('\n')`).
pub fn rstrip_newlines(s : String) -> String {
  let mut end = s.length()
  while end > 0 && s.unsafe_get(end - 1).to_int() == 0x0a {
    end -= 1
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Python's `'%*d' % (width, n)` / `str(n).rjust(width)`.
pub fn rjust(s : String, width : Int, fill? : Char = ' ') -> String {
  let n = s.char_length()
  if n >= width {
    s
  } else {
    String::make(width - n, fill) + s
  }
}
