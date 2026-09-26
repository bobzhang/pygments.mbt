// Hand-written parts of pygments/lexers/testing.py.

///|
/// `GherkinLexer.analyse_text` takes `self` and returns `None`: as a static
/// analyser it always scores 0.
fn gherkin_lexer_analyse(_text : String) -> Double {
  0.0
}
