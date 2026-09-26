// Hand-written parts of pygments/lexers/asc.py.

///|
let asc_begin_re : @regex.Regex = @lexer.re("^-----BEGIN [^\\n]+-----\\r?\\n")

///|
fn asc_lexer_analyse(text : String) -> Double {
  if @lexer.search(asc_begin_re, text) {
    1.0
  } else {
    0.0
  }
}
