// Hand-written parts of pygments/lexers/forth.py.

///|
let forth_definition_re : @regex.Regex = @lexer.re("\n:[^\n]+;\n")

///|
/// Forth uses `: COMMAND ;` quite a lot in a single line.
fn forth_lexer_analyse(text : String) -> Double {
  if @lexer.search(forth_definition_re, text) {
    0.3
  } else {
    0.0
  }
}
