// Hand-written parts of pygments/lexers/maxima.py.

///|
let maxima_terminator_re : @regex.Regex = @lexer.re(
  "\\$\\s*$",
  flags=@regex.MULTILINE,
)

///|
fn maxima_lexer_analyse(text : String) -> Double {
  let mut strength = 0.0
  // input expression terminator
  if @lexer.search(maxima_terminator_re, text) {
    strength += 0.05
  }
  // function definition operator
  if text.contains(":=") {
    strength += 0.02
  }
  strength
}
