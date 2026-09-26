// Hand-written parts of pygments/lexers/bibtex.py.

///|
/// Callbacks of `BibTeXLexer` (an `ExtendedRegexLexer`). The opening brace is
/// per-run state (Python stores it on the `LexerContext`).
fn bib_te_x_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let opening : Ref[String?] = Ref(None)
  Map::from_array([
    (
      "BibTeXLexer.open_brace_callback",
      (ctx, m, _) => {
        let brace = m.matched()
        opening.val = Some(brace)
        ctx.emit(m.start(), @token.punctuation, brace)
        ctx.pos = m.end()
      },
    ),
    (
      "BibTeXLexer.close_brace_callback",
      (ctx, m, _) => {
        let closing = m.matched()
        let mismatched = match opening.val {
          Some("{") => closing != "}"
          Some("(") => closing != ")"
          _ => false
        }
        ctx.emit(
          m.start(),
          if mismatched {
            @token.error
          } else {
            @token.punctuation
          },
          closing,
        )
        opening.val = None
        ctx.pos = m.end()
      },
    ),
  ])
}
