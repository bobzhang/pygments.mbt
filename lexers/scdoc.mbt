// Hand-written parts of pygments/lexers/scdoc.py.

///|
let scdoc_preamble_re : @regex.Regex = @lexer.re(
  "^.*\\([1-7]\\)( \"[^\"]+\"){0,2}$",
)

///|
fn scdoc_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("*") {
    result += 0.01
  }
  if text.contains("_") {
    result += 0.01
  }
  let first_line = match text.find("\n") {
    Some(i) => text.unsafe_substring(start=0, end=i)
    None => text
  }
  if @lexer.search(scdoc_preamble_re, first_line) {
    result += 0.5
  }
  result
}
