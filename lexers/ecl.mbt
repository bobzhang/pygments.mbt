// Hand-written parts of pygments/lexers/ecl.py.

///|
/// `ECLLexer.analyse_text`: `->` together with `BEGIN`/`END` is rare
/// elsewhere.
fn ecl_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("->") {
    result += 0.01
  }
  if text.contains("BEGIN") {
    result += 0.01
  }
  if text.contains("END") {
    result += 0.01
  }
  result
}
