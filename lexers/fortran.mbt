// Hand-written parts of pygments/lexers/fortran.py.

///|
/// Callbacks of `FortranFixedLexer`. `_lex_fortran` lexes a line as free
/// form Fortran (with a default `FortranLexer`) and drops the newlines;
/// like Python, the token offsets are relative to the matched text.
fn fortran_fixed_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let lexer : Ref[@lexer.Lexer?] = Ref(None)
  Map::from_array([
    (
      "FortranFixedLexer._lex_fortran",
      (ctx, m, _) => {
        let fortran = match lexer.val {
          Some(l) => l
          None => {
            let l = fortran_lexer()
            lexer.val = Some(l)
            l
          }
        }
        for t in fortran.get_tokens_unprocessed(m.matched() + "\n") {
          let value = t.value.replace_all(old="\n", new="")
          if value != "" {
            ctx.emit(t.index, t.ttype, value)
          }
        }
      },
    ),
  ])
}
