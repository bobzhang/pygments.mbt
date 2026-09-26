// Hand-written parts of pygments/lexers/slash.py.

///|
/// Callbacks of `SlashLanguageLexer`: a `}` closing a string interpolation
/// also leaves the enclosing `string` state.
fn slash_language_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "SlashLanguageLexer.right_angle_bracket",
      (ctx, m, _) => {
        let n = ctx.stack.length()
        if n > 1 && ctx.def.state_names[ctx.stack[n - 2]] == "string" {
          ctx.stack.pop() |> ignore
        }
        ctx.emit(m.start(), @token.string_interpol, "}")
        ctx.pos = m.end()
      },
    ),
  ])
}
