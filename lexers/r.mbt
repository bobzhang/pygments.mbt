// Hand-written parts of pygments/lexers/r.py.

///|
let s_assign_re : @regex.Regex = @lexer.re("[a-z0-9_\\])\\s]<-(?!-)")

///|
fn s_lexer_analyse(text : String) -> Double {
  if @lexer.search(s_assign_re, text) {
    0.11
  } else {
    0.0
  }
}

///|
/// `RConsoleLexer.get_tokens_unprocessed`.
fn r_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let slexer = s_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut current_code_block = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    if line.has_prefix(">") || line.has_prefix("+") {
      insertions.push(
        (
          current_code_block.length(),
          [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, 2))],
        ),
      )
      current_code_block = current_code_block + pystr_from(line, 2)
    } else {
      if current_code_block != "" {
        out.append(
          @lexer.do_insertions(
            insertions,
            slexer.get_tokens_unprocessed(current_code_block),
          ),
        )
        current_code_block = ""
        insertions = []
      }
      out.push({ index: start, ttype: @token.generic_output, value: line, })
    }
  }
  if current_code_block != "" {
    out.append(
      @lexer.do_insertions(
        insertions,
        slexer.get_tokens_unprocessed(current_code_block),
      ),
    )
  }
  out
}
