// Hand-written parts of pygments/lexers/haskell.py.
// pydata: haskell_cryptol_extra_keywords = L.haskell.CryptolLexer.EXTRA_KEYWORDS

///|
/// `CryptolLexer.get_tokens_unprocessed`.
fn cryptol_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, cryptol_lexer_def.force(), text, ["root"]).map(t => {
    if t.ttype == @token.name &&
      haskell_cryptol_extra_keywords.contains(t.value) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      t
    }
  })
}

///|
/// Python's `line_re.finditer(text)` with `line_re = re.compile('.*?\n')`:
/// the lines of `text` including their newline (a trailing unterminated
/// line is dropped).
fn literate_lines(text : String) -> Array[String] {
  let lines = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.unsafe_get(i) == '\n' {
      lines.push(text.unsafe_substring(start~, end=i + 1))
      start = i + 1
    }
  }
  lines
}

///|
/// Python's `str.lstrip()`.
fn py_lstrip(s : String) -> String {
  let mut i = 0
  for c in s {
    if !@lexer.is_space(c) {
      break
    }
    i += c.utf16_len()
  }
  s.unsafe_substring(start=i, end=s.length())
}

///|
let literate_bird_re : @regex.Regex = @lexer.re("(>[ \\t]*)(.*\\n)")

///|
/// `LiterateLexer.get_tokens_unprocessed`: splits a literate source into
/// code (lexed with `base`) and Bird markers or LaTeX text.
fn literate_tokenize(
  options : @lexer.Options,
  base : @lexer.Lexer,
  text : String,
) -> Array[@lexer.Token] raise {
  let style = match options.get("litstyle") {
    Some(s) => s
    None => {
      let first = py_lstrip(text)
      if first == "" || first.has_prefix("%") || first.has_prefix("\\") {
        "latex"
      } else {
        "bird"
      }
    }
  }
  let code = StringBuilder()
  let mut code_len = 0
  let insertions : Array[(Int, Array[@lexer.Token])] = []
  if style == "bird" {
    for line in literate_lines(text) {
      match literate_bird_re.match_at(line, 0) {
        Some(m) => {
          insertions.push(
            (
              code_len,
              [
                {
                  index: 0,
                  ttype: @token.comment_special,
                  value: m.group(1).unwrap_or(""),
                },
              ],
            ),
          )
          let c = m.group(2).unwrap_or("")
          code.write_string(c)
          code_len += c.length()
        }
        None =>
          insertions.push(
            (code_len, [{ index: 0, ttype: @token.text, value: line, }]),
          )
      }
    }
  } else {
    let lxlexer = tex_lexer(options~)
    let mut codelines = false
    let latex = StringBuilder()
    for line in literate_lines(text) {
      if codelines {
        if py_lstrip(line).has_prefix("\\end{code}") {
          codelines = false
          latex.write_string(line)
        } else {
          code.write_string(line)
          code_len += line.length()
        }
      } else if py_lstrip(line).has_prefix("\\begin{code}") {
        codelines = true
        latex.write_string(line)
        insertions.push(
          (code_len, lxlexer.get_tokens_unprocessed(latex.to_string())),
        )
        latex.reset()
      } else {
        latex.write_string(line)
      }
    }
    insertions.push(
      (code_len, lxlexer.get_tokens_unprocessed(latex.to_string())),
    )
  }
  @lexer.do_insertions(
    insertions,
    base.get_tokens_unprocessed(code.to_string()),
  )
}

///|
fn literate_haskell_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  literate_tokenize(lx.options, haskell_lexer(options=lx.options), text)
}

///|
fn literate_idris_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  literate_tokenize(lx.options, idris_lexer(options=lx.options), text)
}

///|
fn literate_cryptol_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  literate_tokenize(lx.options, cryptol_lexer(options=lx.options), text)
}

///|
/// `LiterateAgdaLexer` always uses the LaTeX style.
fn literate_agda_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let opts : @lexer.Options = Map([])
  for k, v in lx.options {
    opts[k] = v
  }
  opts["litstyle"] = "latex"
  let base = agda_lexer(options=lx.options)
  literate_tokenize(opts, base, text)
}
