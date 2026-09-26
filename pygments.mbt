///|
/// Version of the upstream Pygments release this port follows.
pub let version : String = "2.21.0"

///|
/// Python's `pygments.lex`: the token stream of `code` (preprocessed and
/// filtered by `lexer`).
///
/// ```mbt check
/// test {
///   let lexer = @lexers.get_lexer_by_name("python")
///   let tokens = @pygments.lex("x = 1\n", lexer)
///   inspect(tokens[0].0, content="Token.Name")
///   inspect(tokens.map(t => t.1).join(""), content="x = 1\n")
/// }
/// ```
pub fn lex(
  code : String,
  lexer : @lexer.Lexer,
) -> Array[(@token.TokenType, String)] raise {
  lexer.get_tokens(code)
}

///|
pub using @lexers {
  get_lexer_by_name,
  get_lexer_for_filename,
  get_lexer_for_mimetype,
  guess_lexer,
  guess_lexer_for_filename,
}
