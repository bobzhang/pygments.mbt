// Hand-written parts of pygments/lexers/erlang.py.
// pydata: elixir_keyword = L.erlang.ElixirLexer.KEYWORD
// pydata: elixir_keyword_operator = L.erlang.ElixirLexer.KEYWORD_OPERATOR
// pydata: elixir_builtin = L.erlang.ElixirLexer.BUILTIN
// pydata: elixir_builtin_declaration = L.erlang.ElixirLexer.BUILTIN_DECLARATION
// pydata: elixir_builtin_namespace = L.erlang.ElixirLexer.BUILTIN_NAMESPACE
// pydata: elixir_constant = L.erlang.ElixirLexer.CONSTANT
// pydata: elixir_pseudo_var = L.erlang.ElixirLexer.PSEUDO_VAR

///|
/// `ElixirLexer.get_tokens_unprocessed`: re-tags reserved `Name`s.
fn elixir_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, elixir_lexer_def.force(), text, stack).map(t => {
    if t.ttype != @token.name {
      return t
    }
    let v = t.value
    let ttype = if elixir_keyword.contains(v) {
      @token.keyword
    } else if elixir_keyword_operator.contains(v) {
      @token.operator_word
    } else if elixir_builtin.contains(v) {
      @token.keyword
    } else if elixir_builtin_declaration.contains(v) {
      @token.keyword_declaration
    } else if elixir_builtin_namespace.contains(v) {
      @token.keyword_namespace
    } else if elixir_constant.contains(v) {
      @token.name_constant
    } else if elixir_pseudo_var.contains(v) {
      @token.name_builtin_pseudo
    } else {
      return t
    }
    { ..t, ttype, }
  })
}

///|
let erlang_shell_prompt_re : @regex.Regex = @lexer.re(
  "(?:\\([\\w@_.]+\\))?\\d+>(?=\\s|\\Z)",
)

///|
/// `ErlangShellLexer.get_tokens_unprocessed`.
fn erlang_shell_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let erlexer = erlang_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    match erlang_shell_prompt_re.match_at(line, 0) {
      Some(m) => {
        let end = m.end()
        insertions.push(
          (
            curcode.length(),
            [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, end))],
          ),
        )
        curcode = curcode + pystr_from(line, end)
      }
      None => {
        if curcode != "" {
          out.append(
            @lexer.do_insertions(
              insertions,
              erlexer.get_tokens_unprocessed(curcode),
            ),
          )
          curcode = ""
          insertions = []
        }
        let ttype = if line.has_prefix("*") {
          @token.generic_traceback
        } else {
          @token.generic_output
        }
        out.push({ index: start, ttype, value: line, })
      }
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, erlexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}

///|
let elixir_console_prompt_re : @regex.Regex = @lexer.re(
  "(iex|\\.{3})((?:\\([\\w@_.]+\\))?\\d+|\\(\\d+\\))?> ",
)

///|
/// `ElixirConsoleLexer.get_tokens_unprocessed`.
fn elixir_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let exlexer = elixir_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut in_error = false
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    if line.has_prefix("** ") {
      in_error = true
      insertions.push(
        (
          curcode.length(),
          [pystr_itok(@token.generic_error, @lexer.py_slice(line, 0, -1))],
        ),
      )
      curcode = curcode + @lexer.py_slice(line, -1, line.length())
    } else {
      match elixir_console_prompt_re.match_at(line, 0) {
        Some(m) => {
          in_error = false
          let end = m.end()
          insertions.push(
            (
              curcode.length(),
              [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, end))],
            ),
          )
          curcode = curcode + pystr_from(line, end)
        }
        None => {
          if curcode != "" {
            out.append(
              @lexer.do_insertions(
                insertions,
                exlexer.get_tokens_unprocessed(curcode),
              ),
            )
            curcode = ""
            insertions = []
          }
          let ttype = if in_error {
            @token.generic_error
          } else {
            @token.generic_output
          }
          out.push({ index: start, ttype, value: line, })
        }
      }
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, exlexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
