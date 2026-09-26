// Hand-written parts of pygments/lexers/tcl.py.

///|
fn tcl_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "(tcl)") {
    1.0
  } else {
    0.0
  }
}
