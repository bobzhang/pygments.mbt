// Hand-written parts of pygments/lexers/mojo.py.

///|
/// `MojoLexer.analyse_text`: a `mojo` shebang, or `import ` in the first
/// 1000 characters (code points, as in Python).
fn mojo_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "mojo?") {
    return 1.0
  }
  let head = StringBuilder()
  let mut n = 0
  for c in text {
    if n >= 1000 {
      break
    }
    head.write_char(c)
    n += 1
  }
  if head.to_string().contains("import ") {
    0.9
  } else {
    0.0
  }
}
