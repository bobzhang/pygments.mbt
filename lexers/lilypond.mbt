// Hand-written parts of pygments/lexers/lilypond.py (including the parts
// inherited from `SchemeLexer` in pygments/lexers/lisp.py).
// pydata: lilypond_scheme_keywords = L._scheme_builtins.scheme_keywords
// pydata: lilypond_scheme_builtins = L._scheme_builtins.scheme_builtins
// pydata: lilypond_scheme_functions = set(L._lilypond_builtins.scheme_functions)

///|
let lilypond_scheme_function_tok : @token.TokenType = @token.name_builtin.sub(
  "SchemeFunction",
)

///|
let lilypond_scheme_builtin_tok : @token.TokenType = @token.name_builtin.sub(
  "SchemeBuiltin",
)

///|
/// `SchemeLexer.decimal_cb`.
fn lily_pond_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "SchemeLexer.decimal_cb",
      (ctx, m, _) => {
        let text = m.matched()
        let t = if text.contains(".") {
          @token.number_float
        } else {
          @token.number_integer
        }
        ctx.emit(m.start(), t, text)
      },
    ),
  ])
}

///|
/// `LilyPondLexer.get_tokens_unprocessed` on top of
/// `SchemeLexer.get_tokens_unprocessed`.
fn lily_pond_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let tokens = @lexer.run_regex(
    lx,
    lily_pond_lexer_def.force(),
    text,
    stack,
    callbacks=lily_pond_lexer_callbacks(lx),
  )
  tokens.map(t => {
    // SchemeLexer
    let mut ttype = t.ttype
    if ttype == @token.name_function || ttype == @token.name_variable {
      if lilypond_scheme_keywords.contains(t.value) {
        ttype = @token.keyword
      } else if lilypond_scheme_builtins.contains(t.value) {
        ttype = @token.name_builtin
      }
    }
    // LilyPondLexer
    if ttype == @token.name_function || ttype == @token.name_variable {
      if lilypond_scheme_functions.contains(t.value) {
        ttype = lilypond_scheme_function_tok
      }
    } else if ttype == @token.name_builtin {
      ttype = lilypond_scheme_builtin_tok
    }
    { ..t, ttype, }
  })
}
