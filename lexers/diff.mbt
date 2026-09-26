// Hand-written parts of pygments/lexers/diff.py.

///|
fn diff_lexer_analyse(text : String) -> Double {
  if text.has_prefix("Index: ") || text.has_prefix("diff ") {
    1.0
  } else if text.has_prefix("--- ") {
    0.9
  } else {
    0.0
  }
}
