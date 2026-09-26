// Hand-written parts of pygments/lexers/email.py.

///|
fn email_header_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let highlight_x = @lexer.get_bool_opt(lx.options, "highlight-X-header", false)
  Map::from_array([
    (
      "EmailHeaderLexer.get_x_header_tokens",
      (ctx, m, _) => {
        if highlight_x {
          ctx.emit(m.start(group=1), @token.name_tag, markup_group(m, 1))
          // Python does not re-base these tokens
          ctx.emit_lexed(ctx.lexer, markup_group(m, 2), 0, stack=[
            "root", "header",
          ])
        } else {
          ctx.emit(m.start(group=1), @token.comment_special, markup_group(m, 1))
          ctx.emit(
            m.start(group=2),
            @token.comment_multiline,
            markup_group(m, 2),
          )
        }
      },
    ),
  ])
}

///|
/// `EmailHeaderLexer.__init__` reads the `highlight-X-header` option.
fn email_header_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    email_header_lexer_def.force(),
    text,
    stack,
    callbacks=email_header_lexer_callbacks(lx),
  )
}
