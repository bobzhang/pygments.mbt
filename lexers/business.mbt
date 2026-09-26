// Hand-written parts of pygments/lexers/business.py.

///|
/// `OpenEdgeLexer.analyse_text`: a few common ABL constructs.
fn open_edge_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  for word in ["END.", "END PROCEDURE.", "ELSE DO:"] {
    if text.contains(word) {
      result += 0.05
    }
  }
  result
}
