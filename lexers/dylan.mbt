// Hand-written parts of pygments/lexers/dylan.py.
// pydata: dylan_builtins = L.dylan.DylanLexer.builtins
// pydata: dylan_keywords = L.dylan.DylanLexer.keywords
// pydata: dylan_functions = L.dylan.DylanLexer.functions
// pydata: dylan_operators = L.dylan.DylanLexer.operators

///|
/// `DylanLexer.get_tokens_unprocessed`: re-tags `Name`s (case-insensitively).
fn dylan_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, dylan_lexer_def.force(), text, stack).map(t => {
    if t.ttype != @token.name {
      return t
    }
    let lower = t.value.to_lower()
    let ttype = if dylan_builtins.contains(lower) {
      @token.name_builtin
    } else if dylan_keywords.contains(lower) {
      @token.keyword
    } else if dylan_functions.contains(lower) {
      @token.name_builtin
    } else if dylan_operators.contains(lower) {
      @token.operator
    } else {
      return t
    }
    { ..t, ttype, }
  })
}

///|
let dylan_console_prompt_re : @regex.Regex = @lexer.re("\\?| ")

///|
/// `DylanConsoleLexer.get_tokens_unprocessed`.
fn dylan_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let dylexer = dylan_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    match dylan_console_prompt_re.match_at(line, 0) {
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
              dylexer.get_tokens_unprocessed(curcode),
            ),
          )
          curcode = ""
          insertions = []
        }
        out.push({ index: start, ttype: @token.generic_output, value: line, })
      }
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, dylexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
