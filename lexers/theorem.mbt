// Hand-written parts of pygments/lexers/theorem.py.

///|
fn rocq_lexer_analyse(text : String) -> Double {
  if text.contains("Qed") && text.contains("Proof") {
    1.0
  } else {
    0.0
  }
}
