// Hand-written parts of pygments/lexers/matlab.py.

///|
let matlab_comment_start_re : @regex.Regex = @lexer.re("^\\s*%")

///|
let matlab_comment_line_re : @regex.Regex = @lexer.re(
  "^\\s*%",
  flags=@regex.MULTILINE,
)

///|
let matlab_system_cmd_re : @regex.Regex = @lexer.re(
  "^!\\w+",
  flags=@regex.MULTILINE,
)

///|
fn matlab_lexer_analyse(text : String) -> Double {
  // Python tests `text` (not the line) in the generator's condition, so
  // this is the first line unless the text starts with a comment.
  let first_non_comment = if @lexer.matches(matlab_comment_start_re, text) {
    ""
  } else {
    match pystr_splitlines(text) {
      [first, ..] => pystr_strip(first)
      [] => ""
    }
  }
  if first_non_comment.has_prefix("function") &&
    !first_non_comment.contains("{") {
    1.0
  } else if @lexer.search(matlab_comment_line_re, text) {
    0.2
  } else if @lexer.search(matlab_system_cmd_re, text) {
    0.2
  } else {
    0.0
  }
}

///|
fn octave_lexer_analyse(_text : String) -> Double {
  0.0
}

///|
let scilab_line_comment_re : @regex.Regex = @lexer.re("^\\s*//")

///|
let scilab_block_comment_re : @regex.Regex = @lexer.re("^\\s*/\\*")

///|
fn scilab_lexer_analyse(text : String) -> Double {
  let mut score = 0.0
  if @lexer.search(scilab_line_comment_re, text) {
    score += 0.1
  }
  if @lexer.search(scilab_block_comment_re, text) {
    score += 0.1
  }
  if score < 1.0 {
    score
  } else {
    1.0
  }
}

///|
/// `MatlabSessionLexer.get_tokens_unprocessed`.
fn matlab_session_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let mlexer = matlab_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  let mut continuation = false
  for entry in pystr_lines(text) {
    let (start, line) = entry
    if line.has_prefix(">> ") {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_prompt, ">> ")]),
      )
      curcode = curcode + pystr_from(line, 3)
    } else if line.has_prefix(">>") {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_prompt, ">>")]),
      )
      curcode = curcode + pystr_from(line, 2)
    } else if line.has_prefix("???") {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_traceback, line)]),
      )
    } else if continuation && !insertions.is_empty() {
      // the length of the most recent prompt symbol
      let last = insertions[insertions.length() - 1].1
      let line_start = last[last.length() - 1].value.length()
      if line.has_prefix(" ".repeat(line_start)) {
        insertions.push(
          (
            curcode.length(),
            [
              pystr_itok(
                @token.generic_prompt,
                @lexer.py_slice(line, 0, line_start),
              ),
            ],
          ),
        )
        curcode = curcode + pystr_from(line, line_start)
      } else {
        curcode = curcode + line
      }
    } else {
      if curcode != "" {
        out.append(
          @lexer.do_insertions(
            insertions,
            mlexer.get_tokens_unprocessed(curcode),
          ),
        )
        curcode = ""
        insertions = []
      }
      out.push({ index: start, ttype: @token.generic_output, value: line, })
    }
    continuation = pystr_strip(line).has_suffix("...")
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, mlexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
