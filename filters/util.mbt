///|
/// A token stream: `(token type, text)` pairs.
pub type TokenStream = Array[(@token.TokenType, String)]

///|
/// Python's `_replace_special`: splits `value` at the matches of `regex`,
/// giving the matched parts the type `special` (after `replace`).
fn replace_special(
  out : TokenStream,
  ttype : @token.TokenType,
  value : String,
  regex : @regex.Regex,
  special : @token.TokenType,
  replace? : (String) -> String = s => s,
) -> Unit raise {
  let mut last = 0
  for m in regex.find_all(value) {
    let start = m.start()
    let end = m.end()
    if start != last {
      out.push((ttype, value.unsafe_substring(start=last, end=start)))
    }
    out.push((special, replace(value.unsafe_substring(start~, end~))))
    last = end
  }
  if last != value.length() {
    out.push((ttype, value.unsafe_substring(start=last, end=value.length())))
  }
}

///|
/// Python's `re.escape`.
pub fn re_escape(s : String) -> String {
  let buf = StringBuilder()
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
      | ' ' => buf.write_char('\\')
      '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' => buf.write_char('\\')
      _ => ()
    }
    buf.write_char(c)
  }
  buf.to_string()
}
