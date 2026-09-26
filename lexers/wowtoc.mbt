// Hand-written parts of pygments/lexers/wowtoc.py.

///|
let wowtoc_interface_re : @regex.Regex = @lexer.re(
  "(?i)^(##)( *)(Interface)( *)(:)( *)(.*?)( *)$",
)

///|
let wowtoc_version_re : @regex.Regex = @lexer.re("(\\d+)(\\d{2})(\\d{2})")

///|
fn wo_w_toc_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  let interface = wowtoc_interface_re.search(text) catch { _ => None }
  if interface is Some(m) &&
    @lexer.matches(wowtoc_version_re, markup_group(m, 7)) {
    result += 0.8
  }
  // `text.casefold()` only matters for the ASCII needles below
  let folded = text.to_lower()
  if folded.contains(".lua") {
    result += 0.1
  }
  if folded.contains(".xml") {
    result += 0.05
  }
  result
}
