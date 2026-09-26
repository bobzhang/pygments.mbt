// Hand-written parts of pygments/lexers/javascript.py.
// pydata: lasso_builtins = set().union(*L._lasso_builtins.BUILTINS.values())
// pydata: lasso_members = set().union(*L._lasso_builtins.MEMBERS.values())

///|
/// Python's `s.rstrip(chars)` for a single character.
fn lasso_rstrip_char(s : String, c : Char) -> String {
  let mut end = s.length()
  while end > 0 && s.unsafe_get(end - 1) == c.to_int().to_uint16() {
    end -= 1
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// `LassoLexer.__init__` / `get_tokens_unprocessed`: the
/// `requiredelimiters` option starts in the `delimiters` state, and with
/// `builtinshighlighting` builtin names and members become `Name.Builtin`.
fn lasso_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let builtins_highlighting = @lexer.get_bool_opt(
    lx.options,
    "builtinshighlighting",
    true,
  )
  let require_delimiters = @lexer.get_bool_opt(
    lx.options,
    "requiredelimiters",
    false,
  )
  let stack = ["root"]
  if require_delimiters {
    stack.push("delimiters")
  }
  let name_member = @token.name_other.sub("Member")
  @lexer.run_regex(lx, lasso_lexer_def.force(), text, stack).map(t => {
    if builtins_highlighting &&
      (
        (
          t.ttype == @token.name_other &&
          lasso_builtins.contains(t.value.to_lower())
        ) ||
        (
          t.ttype == name_member &&
          lasso_members.contains(lasso_rstrip_char(t.value.to_lower(), '='))
        )
      ) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      t
    }
  })
}

///|
let lasso_delim_re : @regex.Regex = @lexer.re(
  "<\\?lasso",
  flags=@regex.IGNORECASE,
)

///|
let lasso_local_re : @regex.Regex = @lexer.re(
  "local\\(",
  flags=@regex.IGNORECASE,
)

///|
fn lasso_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if text.contains("bin/lasso9") {
    rv += 0.8
  }
  if @lexer.search(lasso_delim_re, text) {
    rv += 0.4
  }
  if @lexer.search(lasso_local_re, text) {
    rv += 0.4
  }
  rv
}

///|
let objective_j_import_re : @regex.Regex = @lexer.re(
  "^\\s*@import\\s+[<\"]",
  flags=@regex.MULTILINE,
)

///|
fn objective_j_lexer_analyse(text : String) -> Double {
  // special directive found in most Objective-J files
  if @lexer.search(objective_j_import_re, text) {
    1.0
  } else {
    0.0
  }
}

///|
/// Python's `line_re = re.compile('.*?\n')`.
let node_console_line_re : @regex.Regex = @lexer.re(".*?\n")

///|
/// `NodeConsoleLexer.get_tokens_unprocessed`: `> ` and `...` prompts,
/// the code after them lexed as JavaScript.
fn node_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let jslexer = javascript_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let curcode = StringBuilder()
  let mut curcode_len = 0
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for m in node_console_line_re.find_all(text) {
    let line = m.matched()
    if line.has_prefix("> ") {
      insertions.push(
        (
          curcode_len,
          [
            { index: 0, ttype: @token.generic_prompt, value: ">", },
            { index: 1, ttype: @token.whitespace, value: " ", },
          ],
        ),
      )
      let code = @lexer.py_slice(line, 2, line.length())
      curcode.write_string(code)
      curcode_len += code.length()
    } else if line.has_prefix("...") {
      // node does a nested ... thing depending on depth
      let mut lead = 0
      while lead < line.length() && line.unsafe_get(lead) == '.' {
        lead += 1
      }
      let code = @lexer.py_slice(line, lead, line.length())
      insertions.push(
        (
          curcode_len,
          [
            {
              index: 0,
              ttype: @token.generic_prompt,
              value: @lexer.py_slice(line, 0, lead),
            },
          ],
        ),
      )
      curcode.write_string(code)
      curcode_len += code.length()
    } else {
      if curcode_len > 0 {
        out.append(
          @lexer.do_insertions(
            insertions,
            jslexer.get_tokens_unprocessed(curcode.to_string()),
          ),
        )
        curcode.reset()
        curcode_len = 0
        insertions = []
      }
      out.append(@lexer.do_insertions([], jslexer.get_tokens_unprocessed(line)))
    }
  }
  if curcode_len > 0 {
    out.append(
      @lexer.do_insertions(
        insertions,
        jslexer.get_tokens_unprocessed(curcode.to_string()),
      ),
    )
  }
  out
}
