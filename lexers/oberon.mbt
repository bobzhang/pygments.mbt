// Hand-written parts of pygments/lexers/oberon.py.

///|
/// `ComponentPascalLexer.analyse_text`: a few common Pascal keywords.
fn component_pascal_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  for word in ["BEGIN", "END", "PROCEDURE", "MODULE"] {
    if text.contains(word) {
      result += 0.01
    }
  }
  result
}
