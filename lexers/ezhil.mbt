// Hand-written parts of pygments/lexers/ezhil.py.

///|
/// `EzhilLexer.__init__` only records the `encoding` option, which does not
/// affect tokenization of text.
fn ezhil_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, ezhil_lexer_def.force(), text, stack)
}

///|
/// `EzhilLexer.analyse_text`: more than 10 Tamil characters.
fn ezhil_lexer_analyse(text : String) -> Double {
  let mut n = 0
  for c in text {
    if c >= '\u{0b80}' && c <= '\u{0bff}' {
      n += 1
    }
  }
  if n > 10 {
    0.25
  } else {
    0.0
  }
}
