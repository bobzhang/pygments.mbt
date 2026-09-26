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

///|
/// Python's `pygments.format`: renders a token stream with `formatter`.
pub fn format(
  tokens : Array[(@token.TokenType, String)],
  formatter : @formatters.Formatter,
) -> String raise {
  formatter.format(tokens)
}

///|
/// Python's `pygments.highlight`: lexes `code` with `lexer` and renders it
/// with `formatter`.
///
/// ```mbt check
/// test {
///   let html = @pygments.highlight(
///     "x = 1\n",
///     @pygments.get_lexer_by_name("python"),
///     @pygments.get_formatter_by_name("html"),
///   )
///   inspect(
///     html,
///     content=(
///       #|<div class="highlight"><pre><span></span><span class="n">x</span> <span class="o">=</span> <span class="mi">1</span>
///       #|</pre></div>
///       #|
///     ),
///   )
/// }
/// ```
pub fn highlight(
  code : String,
  lexer : @lexer.Lexer,
  formatter : @formatters.Formatter,
) -> String raise {
  @formatters.highlight(code, lexer, formatter)
}

///|
pub using @formatters {get_formatter_by_name, get_formatter_for_filename}
