// Hand-written parts of pygments/lexers/julia.py.

///|
fn julia_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "julia") {
    1.0
  } else {
    0.0
  }
}

///|
/// `JuliaConsoleLexer.get_tokens_unprocessed`.
fn julia_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let jllexer = julia_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut start = 0
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  let mut output = false
  let mut error = false
  for line in pystr_splitlines(text, keepends=true) {
    if line.has_prefix("julia>") {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_prompt, "julia>")]),
      )
      curcode = curcode + pystr_from(line, 6)
      output = false
      error = false
    } else if line.has_prefix("help?>") || line.has_prefix("shell>") {
      out.push({
        index: start,
        ttype: @token.generic_prompt,
        value: @lexer.py_slice(line, 0, 6),
      })
      out.push({
        index: start + 6,
        ttype: @token.text,
        value: pystr_from(line, 6),
      })
      output = false
      error = false
    } else if line.has_prefix("      ") && !output {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.whitespace, "      ")]),
      )
      curcode = curcode + pystr_from(line, 6)
    } else {
      if curcode != "" {
        out.append(
          @lexer.do_insertions(
            insertions,
            jllexer.get_tokens_unprocessed(curcode),
          ),
        )
        curcode = ""
        insertions = []
      }
      if line.has_prefix("ERROR: ") || error {
        out.push({ index: start, ttype: @token.generic_error, value: line, })
        error = true
      } else {
        out.push({ index: start, ttype: @token.generic_output, value: line, })
      }
      output = true
    }
    start += line.length()
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, jllexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
