// Hand-written parts of pygments/lexers/installers.py.

///|
fn sources_list_lexer_analyse(text : String) -> Double {
  for line in splitlines(text) {
    let line = markup_strip(line)
    if line.has_prefix("deb ") || line.has_prefix("deb-src ") {
      return 1.0
    }
  }
  0.0
}
