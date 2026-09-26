// Hand-written parts of pygments/lexers/crystal.py.

///|
fn crystal_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let stacks : HeredocStacks = { entries: [], }
  {
    "CrystalLexer.heredoc_callback": (ctx, m, _) => {
      heredoc_callback(stacks, ctx, m, ["<<-"], false)
    },
  }
}
