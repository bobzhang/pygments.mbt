// Hand-written parts of pygments/lexers/ml.py.
// pydata: ml_sml_alphanumid_reserved = L.ml.SMLLexer.alphanumid_reserved
// pydata: ml_sml_symbolicid_reserved = L.ml.SMLLexer.symbolicid_reserved

///|
/// Callbacks of `SMLLexer` distinguishing identifiers from reserved words.
fn sml_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "SMLLexer.long_id_callback",
      (ctx, m, _) => {
        let id = m.group(1).unwrap_or("")
        let ttype = if ml_sml_alphanumid_reserved.contains(id) {
          @token.error
        } else {
          @token.name_namespace
        }
        ctx.emit(m.start(group=1), ttype, id)
        ctx.emit(m.start(group=2), @token.punctuation, m.group(2).unwrap_or(""))
      },
    ),
    (
      "SMLLexer.end_id_callback",
      (ctx, m, _) => {
        let id = m.group(1).unwrap_or("")
        let ttype = if ml_sml_alphanumid_reserved.contains(id) ||
          ml_sml_symbolicid_reserved.contains(id) {
          @token.error
        } else {
          @token.name
        }
        ctx.emit(m.start(group=1), ttype, id)
      },
    ),
    (
      "SMLLexer.id_callback",
      (ctx, m, _) => {
        let id = m.group(1).unwrap_or("")
        let ttype = if ml_sml_alphanumid_reserved.contains(id) {
          @token.keyword_reserved
        } else if ml_sml_symbolicid_reserved.contains(id) {
          @token.punctuation
        } else {
          @token.name
        }
        ctx.emit(m.start(group=1), ttype, id)
      },
    ),
  ])
}
