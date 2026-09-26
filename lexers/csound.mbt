// Hand-written parts of pygments/lexers/csound.py.
// pydata: csound_opcodes = L._csound_builtins.OPCODES
// pydata: csound_deprecated_opcodes = L._csound_builtins.DEPRECATED_OPCODES
// pydata: csound_removed_opcodes = L._csound_builtins.REMOVED_OPCODES

///|
/// `CsoundOrchestraLexer.user_defined_opcodes`: a class attribute in Python,
/// so opcodes defined in one text stay known for every later lexer run.
let csound_user_defined_opcodes : @set.Set[String] = @set.Set([])

///|
let csound_type_annotation_re : @regex.Regex = @lexer.re("^(g?[afikSw])(\\w+)")

///|
fn csound_orchestra_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "CsoundOrchestraLexer.name_callback",
      (ctx, m, _) => {
        let mut type_annotation_token = @token.keyword_type
        let name = markup_group(m, 1)
        if csound_opcodes.contains(name) ||
          csound_deprecated_opcodes.contains(name) ||
          csound_removed_opcodes.contains(name) {
          ctx.emit(m.start(), @token.name_builtin, name)
        } else if csound_user_defined_opcodes.contains(name) {
          ctx.emit(m.start(), @token.name_function, name)
        } else {
          type_annotation_token = @token.name
          match csound_type_annotation_re.search(name) {
            // Python yields offsets relative to `name` here
            Some(nm) => {
              ctx.emit(
                nm.start(group=1),
                @token.keyword_type,
                markup_group(nm, 1),
              )
              ctx.emit(nm.start(group=2), @token.name, markup_group(nm, 2))
            }
            None => ctx.emit(m.start(), @token.name, name)
          }
        }
        if markup_group(m, 2) != "" {
          ctx.emit(m.start(group=2), @token.punctuation, markup_group(m, 2))
          ctx.emit(m.start(group=3), type_annotation_token, markup_group(m, 3))
        }
      },
    ),
    (
      "CsoundOrchestraLexer.opcode_name_callback",
      (ctx, m, _) => {
        let opcode = m.matched()
        csound_user_defined_opcodes.add(opcode)
        ctx.emit(m.start(), @token.name_function, opcode)
      },
    ),
  ])
}
