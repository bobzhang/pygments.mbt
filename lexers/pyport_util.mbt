// Small ports of Python string helpers shared by the hand-written lexers
// (shell, special, console lexers, analysers).

///|
/// Python's `line_re.finditer(text)` (`.*?\n`): every line ending with a
/// newline, with its start offset. A trailing line without `\n` is dropped.
fn pystr_lines(text : String) -> Array[(Int, String)] {
  let out = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.unsafe_get(i) == '\n' {
      out.push((start, text.unsafe_substring(start~, end=i + 1)))
      start = i + 1
    }
  }
  out
}

///|
/// Late-bound `get_lexer_by_name`. Constructors cannot refer to it directly:
/// that would make `all_lexers` (which refers to every constructor) part of
/// a definition cycle, so it is installed by `init`.
let pyport_lexer_lookup : Ref[(String, @lexer.Options) -> @lexer.Lexer raise] = Ref((
    name,
    _,
  ) => raise ClassNotFound("no lexer for lexer_alias \{name.escape()} found"),
)

///|
fn init {
  pyport_lexer_lookup.val = (name, options) => get_lexer_by_name(name, options~)
}

///|
/// Python's `get_lexer_by_name(name, **options)` for hand-written lexers.
fn pyport_get_lexer_by_name(
  name : String,
  options : @lexer.Options,
) -> @lexer.Lexer raise {
  (pyport_lexer_lookup.val)(name, options)
}

///|
/// A single token at offset 0 (the shape of Python's insertion lists).
fn pystr_itok(ttype : @token.TokenType, value : String) -> @lexer.Token {
  { index: 0, ttype, value, }
}

///|
/// Python's `text[:n]`: the first `n` code points of `text`.
fn pystr_prefix(text : String, n : Int) -> String {
  text.unsafe_substring(start=0, end=pystr_cp_advance(text, 0, n))
}

///|
/// The UTF-16 offset `n` code points after `pos` (clamped to the end).
fn pystr_cp_advance(text : String, pos : Int, n : Int) -> Int {
  let len = text.length()
  let mut i = pos
  let mut k = 0
  while i < len && k < n {
    let c = text.unsafe_get(i).to_int()
    i += if c >= 0xD800 && c <= 0xDBFF && i + 1 < len { 2 } else { 1 }
    k += 1
  }
  i
}

///|
/// The UTF-16 offset `n` code points before `pos` (clamped to 0).
fn pystr_cp_retreat(text : String, pos : Int, n : Int) -> Int {
  let mut i = pos
  let mut k = 0
  while i > 0 && k < n {
    let c = text.unsafe_get(i - 1).to_int()
    i -= if c >= 0xDC00 && c <= 0xDFFF && i >= 2 { 2 } else { 1 }
    k += 1
  }
  i
}

///|
/// Python's `str.strip()` (whitespace as in `str.isspace`).
fn pystr_strip(s : String) -> String {
  let chars = s.to_array()
  let mut a = 0
  let mut b = chars.length()
  while a < b && @lexer.is_space(chars[a]) {
    a += 1
  }
  while b > a && @lexer.is_space(chars[b - 1]) {
    b -= 1
  }
  String::from_array(chars[a:b])
}

///|
/// Python's `str.rstrip()`.
fn pystr_rstrip(s : String) -> String {
  let chars = s.to_array()
  let mut b = chars.length()
  while b > 0 && @lexer.is_space(chars[b - 1]) {
    b -= 1
  }
  String::from_array(chars[0:b])
}

///|
/// Python's `str.split(sep)` for a non-empty separator.
fn pystr_split(s : String, sep : String) -> Array[String] {
  s.split(sep).map(x => x.to_owned()).collect()
}

///|
/// Python's `str[a:]` with a UTF-16 offset.
fn pystr_from(s : String, start : Int) -> String {
  @lexer.py_slice(s, start, s.length())
}

///|
/// Python's `s.find(sub, start)` (UTF-16 offsets); `-1` when absent.
fn pystr_find(s : String, sub : String, start : Int) -> Int {
  let start = if start < 0 { 0 } else { start }
  if start > s.length() {
    return -1
  }
  match s.unsafe_substring(start~, end=s.length()).find(sub) {
    Some(i) => start + i
    None => -1
  }
}

///|
/// Python's `re.escape`.
fn pystr_re_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    match c {
      '('
      | ')'
      | '['
      | ']'
      | '{'
      | '}'
      | '?'
      | '*'
      | '+'
      | '-'
      | '|'
      | '^'
      | '$'
      | '\\'
      | '.'
      | '&'
      | '~'
      | '#'
      | ' '
      | '\t'
      | '\n'
      | '\r'
      | '\u{0b}'
      | '\u{0c}' => {
        sb.write_char('\\')
        sb.write_char(c)
      }
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Python's `str.splitlines(keepends)`.
fn pystr_splitlines(s : String, keepends? : Bool = false) -> Array[String] {
  let out = []
  let buf = StringBuilder()
  let chars = s.to_array()
  let mut i = 0
  let mut pending = false
  while i < chars.length() {
    let c = chars[i]
    match c {
      '\n'
      | '\r'
      | '\u{0b}'
      | '\u{0c}'
      | '\u{1c}'
      | '\u{1d}'
      | '\u{1e}'
      | '\u{85}'
      | '\u{2028}'
      | '\u{2029}' => {
        if keepends {
          buf.write_char(c)
        }
        if c == '\r' && i + 1 < chars.length() && chars[i + 1] == '\n' {
          i += 1
          if keepends {
            buf.write_char('\n')
          }
        }
        out.push(buf.to_string())
        buf.reset()
        pending = false
      }
      _ => {
        buf.write_char(c)
        pending = true
      }
    }
    i += 1
  }
  if pending {
    out.push(buf.to_string())
  }
  out
}
