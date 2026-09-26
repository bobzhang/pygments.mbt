// Hand-written parts of pygments/lexers/make.py.

///|
let makefile_special_re : @regex.Regex = @lexer.re(
  "^(?:\\.\\s*(include|undef|error|warning|if|else|elif|endif|for|endfor)|" +
  "\\s*(ifeq|ifneq|ifdef|ifndef|else|endif|-?include|define|endef|:|vpath)|" +
  "\\s*(if|else|endif))(?=\\s)",
)

///|
let makefile_comment_re : @regex.Regex = @lexer.re("^\\s*@?#")

///|
/// `MakefileLexer.get_tokens_unprocessed`: preprocessor lines and comments
/// are split off; the rest is lexed with `BaseMakefileLexer`.
fn makefile_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let ins : Array[(Int, Array[@lexer.Token])] = []
  let done = StringBuilder()
  let mut done_len = 0
  let lex = base_makefile_lexer(options=lx.options)
  let mut backslashflag = false
  for line in markup_splitlines_keepends(text) {
    if @lexer.matches(makefile_special_re, line) || backslashflag {
      ins.push(
        (done_len, [{ index: 0, ttype: @token.comment_preproc, value: line, }]),
      )
      backslashflag = markup_strip(line).has_suffix("\\")
    } else if @lexer.matches(makefile_comment_re, line) {
      ins.push((done_len, [{ index: 0, ttype: @token.comment, value: line, }]))
    } else {
      done.write_string(line)
      done_len += line.length()
    }
  }
  @lexer.do_insertions(ins, lex.get_tokens_unprocessed(done.to_string()))
}

///|
let makefile_var_re : @regex.Regex = @lexer.re("\\$\\([A-Z_]+\\)")

///|
fn makefile_lexer_analyse(text : String) -> Double {
  if @lexer.search(makefile_var_re, text) {
    0.1
  } else {
    0.0
  }
}

///|
let cmake_minimum_re : @regex.Regex = @lexer.re(
  "^[ \\t]*CMAKE_MINIMUM_REQUIRED[ \\t]*" +
  "\\([ \\t]*VERSION[ \\t]*\\d+(\\.\\d+)*[ \\t]*" +
  "([ \\t]FATAL_ERROR)?[ \\t]*\\)[ \\t]*" +
  "(#[^\\n]*)?$",
  flags=@regex.MULTILINE | @regex.IGNORECASE,
)

///|
fn c_make_lexer_analyse(text : String) -> Double {
  if @lexer.search(cmake_minimum_re, text) {
    0.8
  } else {
    0.0
  }
}
