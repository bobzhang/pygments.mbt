// Hand-written parts of pygments/lexers/bdd.py.

///|
/// `BddLexer.analyse_text` takes `self` and returns `None`: as a static
/// analyser it always scores 0.
fn bdd_lexer_analyse(_text : String) -> Double {
  0.0
}
