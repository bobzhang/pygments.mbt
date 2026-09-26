// Hand-written parts of pygments/lexers/lean.py.

///|
let lean3_import_re : @regex.Regex = @lexer.re(
  "^import [a-z]",
  flags=@regex.MULTILINE,
)

///|
let lean4_import_re : @regex.Regex = @lexer.re(
  "^import [A-Z]",
  flags=@regex.MULTILINE,
)

///|
fn lean3_lexer_analyse(text : String) -> Double {
  if @lexer.search(lean3_import_re, text) {
    0.1
  } else {
    0.0
  }
}

///|
fn lean4_lexer_analyse(text : String) -> Double {
  if @lexer.search(lean4_import_re, text) {
    0.1
  } else {
    0.0
  }
}
