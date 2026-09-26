// Hand-written parts of pygments/lexers/resource.py.

///|
fn resource_lexer_analyse(text : String) -> Double {
  if text.has_prefix("root:table") {
    1.0
  } else {
    0.0
  }
}
