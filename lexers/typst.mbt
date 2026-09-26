// Hand-written parts of pygments/lexers/typst.py.

///|
/// `TypstLexer.get_tokens_unprocessed`: the `start` option (`markup`,
/// `code` or `math`) selects the initial state.
fn typst_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let start_state = @lexer.get_choice_opt(
    lx.options,
    "start",
    ["markup", "code", "math"],
    "markup",
    normcase=true,
  )
  let stack = ["root"]
  if start_state != "markup" {
    stack.push(start_state)
  }
  @lexer.run_regex(lx, typst_lexer_def.force(), text, stack)
}
