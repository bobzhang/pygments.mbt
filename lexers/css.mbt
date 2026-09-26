// Hand-written parts of pygments/lexers/css.py.

///|
/// The module-level callbacks `_indentation` and `_starts_block(token,
/// state)` shared by the indentation-based lexers (Sass, Haml, Scaml, Pug,
/// Slim). Python stores `last_indentation`, `block_state` and
/// `block_indentation` on the `LexerContext`, i.e. per run.
fn css_indentation_callbacks() -> Map[String, @lexer.CallbackFn] {
  let last_indentation : Ref[String?] = Ref(None)
  let block_state : Ref[String?] = Ref(None)
  let block_indentation : Ref[String] = Ref("")
  Map::from_array([
    (
      "_indentation",
      (ctx, m, _) => {
        let indentation = m.matched()
        ctx.emit(m.start(), @token.whitespace, indentation)
        last_indentation.val = Some(indentation)
        ctx.pos = m.end()
        match block_state.val {
          Some(state) if indentation.has_prefix(block_indentation.val) &&
            indentation != block_indentation.val => ctx.push_state(state)
          _ => {
            block_state.val = None
            block_indentation.val = ""
            ctx.push_state("content")
          }
        }
      },
    ),
    (
      "_starts_block",
      (ctx, m, args) => {
        guard args is [Str(state), Tok(token)] else {
          fail("_starts_block: unexpected arguments")
        }
        ctx.emit(m.start(), token, m.matched())
        block_indentation.val = last_indentation.val.unwrap_or("")
        block_state.val = Some(state)
        ctx.pos = m.end()
      },
    ),
  ])
}

///|
fn sass_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  css_indentation_callbacks()
}
