// Hand-written parts of pygments/lexers/carbon.py.

///|
/// `CarbonLexer.analyse_text`: 0.1 per Carbon keyword found.
fn carbon_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  let words = [
    "forall", "type", "Self", "observe", "package", "library", "choice", "addr",
    "constraint", "impl",
  ]
  for word in words {
    if text.contains(word) {
      result += 0.1
    }
  }
  result
}
