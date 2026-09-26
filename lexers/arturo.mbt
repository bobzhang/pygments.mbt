// Hand-written parts of pygments/lexers/arturo.py.

///|
/// Callbacks of `ArturoLexer`: annotated strings (`{!lang ...}`) are lexed
/// with the lexer named by the annotation when `handle_annotateds` is set.
fn arturo_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let handle_annotateds = @lexer.get_bool_opt(
    lx.options,
    "handle_annotateds",
    true,
  )
  Map::from_array([
    (
      "ArturoLexer.handle_annotated_strings",
      (ctx, m, _) => {
        let g = (i : Int) => m.group(i).unwrap_or("")
        ctx.emit(m.start(group=1), @token.string_double, g(1))
        ctx.emit(m.start(group=2), @token.string_interpol, g(2))
        ctx.emit(m.start(group=3), @token.string_interpol, g(3))
        ctx.emit(m.start(group=4), @token.text_whitespace, g(4))
        let lexer = if handle_annotateds {
          Some(lookup_lexer(g(3).trim().to_owned())) catch {
            ClassNotFound(_) => None
            e => raise e
          }
        } else {
          None
        }
        let code = g(5)
        match lexer {
          // Python yields `match.group(5)` as the index here.
          None => ctx.emit(m.start(group=5), @token.string, code)
          // Python does not shift these offsets to the match position.
          Some(l) => ctx.out.append(l.get_tokens_unprocessed(code))
        }
        ctx.emit(m.start(group=6), @token.string_double, g(6))
      },
    ),
  ])
}

///|
/// `ArturoLexer.__init__` reads the `handle_annotateds` option.
fn arturo_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    arturo_lexer_def.force(),
    text,
    stack,
    callbacks=arturo_lexer_callbacks(lx),
  )
}
