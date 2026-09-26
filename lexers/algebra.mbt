// Hand-written parts of pygments/lexers/algebra.py.

///|
let gap_declaration_re : @regex.Regex = @lexer.re(
  "(InstallTrueMethod|Declare(Attribute|Category|Filter|Operation" +
  "|GlobalFunction|Synonym|SynonymAttr|Property))",
)

///|
let gap_implementation_re : @regex.Regex = @lexer.re(
  "(DeclareRepresentation|Install(GlobalFunction|Method|" +
  "ImmediateMethod|OtherMethod)|New(Family|Type)|Objectify)",
)

///|
fn gap_lexer_analyse(text : String) -> Double {
  let mut score = 0.0
  if @lexer.search(gap_declaration_re, text) {
    score += 0.7
  }
  if @lexer.search(gap_implementation_re, text) {
    score += 0.7
  }
  if score < 1.0 {
    score
  } else {
    1.0
  }
}

///|
let gap_console_prompt_re : @regex.Regex = @lexer.re("^gap> ")

///|
fn gap_console_lexer_analyse(text : String) -> Double {
  if @lexer.search(gap_console_prompt_re, text) {
    0.9
  } else {
    0.0
  }
}

///|
/// `GAPConsoleLexer.get_tokens_unprocessed`.
fn gap_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let gaplexer = gap_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut start = 0
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  let mut output = false
  let mut error = false
  for line in pystr_splitlines(text, keepends=true) {
    if line.has_prefix("gap> ") || line.has_prefix("brk> ") {
      insertions.push(
        (
          curcode.length(),
          [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, 5))],
        ),
      )
      curcode = curcode + pystr_from(line, 5)
      output = false
      error = false
    } else if !output && line.has_prefix("> ") {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_prompt, "> ")]),
      )
      curcode = curcode + pystr_from(line, 2)
    } else {
      if curcode != "" {
        out.append(
          @lexer.do_insertions(
            insertions,
            gaplexer.get_tokens_unprocessed(curcode),
          ),
        )
        curcode = ""
        insertions = []
      }
      if line.has_prefix("Error, ") || error {
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
      @lexer.do_insertions(insertions, gaplexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
