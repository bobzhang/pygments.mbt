// Hand-written parts of pygments/lexers/freefem.py.
// pydata: freefem_operators = L.freefem.FreeFemLexer.operators
// pydata: freefem_types = L.freefem.FreeFemLexer.types
// pydata: freefem_fespaces = L.freefem.FreeFemLexer.fespaces
// pydata: freefem_preprocessor = L.freefem.FreeFemLexer.preprocessor
// pydata: freefem_keywords = L.freefem.FreeFemLexer.keywords
// pydata: freefem_functions = L.freefem.FreeFemLexer.functions
// pydata: freefem_parameters = L.freefem.FreeFemLexer.parameters
// pydata: freefem_suppress_highlight = L.freefem.FreeFemLexer.suppress_highlight

///|
/// `FreeFemLexer.get_tokens_unprocessed`: the C++ tokens re-tagged by value,
/// whatever their token type.
fn free_fem_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, free_fem_lexer_def.force(), text, stack).map(t => {
    let v = t.value
    let ttype = if freefem_operators.contains(v) {
      @token.operator
    } else if freefem_types.contains(v) {
      @token.keyword_type
    } else if freefem_fespaces.contains(v) {
      @token.name_class
    } else if freefem_preprocessor.contains(v) {
      @token.comment_preproc
    } else if freefem_keywords.contains(v) {
      @token.keyword_reserved
    } else if freefem_functions.contains(v) {
      @token.name_function
    } else if freefem_parameters.contains(v) {
      @token.keyword_pseudo
    } else if freefem_suppress_highlight.contains(v) {
      @token.name
    } else {
      t.ttype
    }
    { ..t, ttype, }
  })
}

///|
fn free_fem_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}
