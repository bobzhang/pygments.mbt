// Hand-written parts of pygments/lexers/unicon.py.

///|
/// `UcodeLexer.analyse_text`: `endsuspend`, `endrepeat`, `\self`/`/self`.
fn ucode_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("endsuspend") {
    result += 0.1
  }
  if text.contains("endrepeat") {
    result += 0.1
  }
  if text.contains(":=") {
    result += 0.01
  }
  if text.contains("procedure") && text.contains("end") {
    result += 0.01
  }
  if text.contains("\\self") && text.contains("/self") {
    result += 0.5
  }
  result
}
