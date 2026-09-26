// Hand-written parts of pygments/lexers/pawn.py.
// pydata: sourcepawn_sm_types = L.pawn.SourcePawnLexer.SM_TYPES
// pydata: sourcepawn_functions = set(L._sourcemod_builtins.FUNCTIONS)

///|
/// `SourcePawnLexer.__init__` and `get_tokens_unprocessed`: with the
/// `sourcemod` option (default on), SourceMod types and functions are
/// re-tagged.
fn source_pawn_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let smhighlighting = @lexer.get_bool_opt(lx.options, "sourcemod", true)
  let tokens = @lexer.run_regex(lx, source_pawn_lexer_def.force(), text, stack)
  if !smhighlighting {
    return tokens
  }
  tokens.map(t => {
    if t.ttype != @token.name {
      t
    } else if sourcepawn_sm_types.contains(t.value) {
      { ..t, ttype: @token.keyword_type, }
    } else if sourcepawn_functions.contains(t.value) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      t
    }
  })
}

///|
/// `PawnLexer.analyse_text`: `tagof` is nearly unique to Pawn.
fn pawn_lexer_analyse(text : String) -> Double {
  if text.contains("tagof") {
    0.01
  } else {
    0.0
  }
}
