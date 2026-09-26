// Hand-written parts of pygments/lexers/php.py.
// pydata: php_builtin_modules = L._php_builtins.MODULES

///|
/// `PhpLexer.__init__` + `get_tokens_unprocessed`.
fn php_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let funcnamehighlighting = @lexer.get_bool_opt(
    lx.options,
    "funcnamehighlighting",
    true,
  )
  let disabledmodules = @lexer.get_list_opt(lx.options, "disabledmodules", [
    "unknown",
  ])
  let startinline = if lx.options.contains("_startinline") {
    @lexer.get_bool_opt(lx.options, "_startinline", false)
  } else {
    @lexer.get_bool_opt(lx.options, "startinline", false)
  }
  let functions : @set.Set[String] = @set.Set([])
  if funcnamehighlighting {
    for key, value in php_builtin_modules {
      if !disabledmodules.contains(key) {
        for f in value {
          functions.add(f)
        }
      }
    }
  }
  let stack = if startinline { ["root", "php"] } else { ["root"] }
  @lexer.run_regex(lx, php_lexer_def.force(), text, stack).map(t => {
    if t.ttype == @token.name_other && functions.contains(t.value) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      t
    }
  })
}

///|
let php_open_tag_re : @regex.Regex = @lexer.re("<\\?(?!xml)")

///|
fn php_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "php") {
    return 1.0
  }
  if @lexer.search(php_open_tag_re, text) {
    0.3
  } else {
    0.0
  }
}

///|
/// `PsyshConsoleLexer.get_tokens_unprocessed` (the inner `PhpLexer` always
/// gets `startinline=True`).
fn psysh_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let opts = lx.options.copy()
  opts["startinline"] = "True"
  let phplexer = php_lexer(options=opts)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    if line.has_prefix(">>> ") || line.has_prefix("... ") {
      insertions.push(
        (
          curcode.length(),
          [
            pystr_itok(
              @token.generic_prompt,
              line.unsafe_substring(start=0, end=4),
            ),
          ],
        ),
      )
      curcode = curcode + pystr_from(line, 4)
    } else if pystr_rstrip(line) == "..." {
      insertions.push(
        (curcode.length(), [pystr_itok(@token.generic_prompt, "...")]),
      )
      curcode = curcode + pystr_from(line, 3)
    } else {
      if curcode != "" {
        out.append(
          @lexer.do_insertions(
            insertions,
            phplexer.get_tokens_unprocessed(curcode),
          ),
        )
        curcode = ""
        insertions = []
      }
      out.push({ index: start, ttype: @token.generic_output, value: line, })
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, phplexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
