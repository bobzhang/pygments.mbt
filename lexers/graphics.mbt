// Hand-written parts of pygments/lexers/graphics.py.
// pydata: asy_funcnames = L._asy_builtins.ASYFUNCNAME
// pydata: asy_varnames = L._asy_builtins.ASYVARNAME

///|
/// `AsymptoteLexer.get_tokens_unprocessed`: re-tags builtin function and
/// variable names.
fn asymptote_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, asymptote_lexer_def.force(), text, stack).map(t => {
    if t.ttype == @token.name && asy_funcnames.contains(t.value) {
      { ..t, ttype: @token.name_function, }
    } else if t.ttype == @token.name && asy_varnames.contains(t.value) {
      { ..t, ttype: @token.name_variable, }
    } else {
      t
    }
  })
}

///|
fn povray_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("#version") {
    result += 0.05
  }
  if text.contains("#declare") {
    result += 0.05
  }
  if text.contains("camera") {
    result += 0.05
  }
  if text.contains("light_source") {
    result += 0.1
  }
  result
}
