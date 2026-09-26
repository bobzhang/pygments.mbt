// Hand-written parts of pygments/lexers/inferno.py.

///|
let limbo_implement_re : @regex.Regex = @lexer.re(
  "^implement \\w+;",
  flags=@regex.MULTILINE,
)

///|
/// `LimboLexer.analyse_text`: any Limbo module implements something.
fn limbo_lexer_analyse(text : String) -> Double {
  if @lexer.search(limbo_implement_re, text) {
    0.7
  } else {
    0.0
  }
}
