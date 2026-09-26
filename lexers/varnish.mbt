// Hand-written parts of pygments/lexers/varnish.py.

///|
fn vcl_lexer_analyse(text : String) -> Double {
  // If the very first line is 'vcl 4.0;' it's pretty much guaranteed
  // that this is VCL
  if text.has_prefix("vcl 4.0;") {
    1.0
  } else if tal_head(text, 1000).contains("\nvcl 4.0;") {
    // Skip over comments and blank lines
    0.9
  } else {
    0.0
  }
}

///|
/// `VCLSnippetLexer` overrides the analyser inherited from `VCLLexer`.
fn vcl_snippet_lexer_analyse(_text : String) -> Double {
  0.0
}
