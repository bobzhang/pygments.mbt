// Hand-written parts of pygments/lexers/supercollider.py.

///|
/// Searches for a common function and a unique keyword.
fn super_collider_lexer_analyse(text : String) -> Double {
  if text.contains("SinOsc") || text.contains("thisFunctionDef") {
    0.1
  } else {
    0.0
  }
}
