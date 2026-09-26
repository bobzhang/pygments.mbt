// Hand-written parts of pygments/lexers/shell.py.

///|
fn bash_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "(ba|z|)sh") {
    1.0
  } else if text.has_prefix("$ ") {
    0.2
  } else {
    0.0
  }
}

///|
fn slurm_bash_lexer_analyse(text : String) -> Double {
  bash_lexer_analyse(text)
}

///|
fn slurm_bash_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, slurm_bash_lexer_def.force(), text, stack).map(t => {
    if t.ttype == @token.text && t.value == "srun" {
      { ..t, ttype: @token.name_builtin, }
    } else if t.ttype == @token.comment_single && t.value.contains("SBATCH") {
      { ..t, ttype: @token.keyword_pseudo, }
    } else {
      t
    }
  })
}

///|
fn execline_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "execlineb") {
    1.0
  } else {
    0.0
  }
}

///|
let shell_venv_re : @regex.Regex = @lexer.re("^(\\([^)]*\\))(\\s*)")

///|
/// `ShellSessionBaseLexer.get_tokens_unprocessed`.
fn shell_session_tokenize(
  inner : @lexer.Lexer,
  ps1 : @regex.Regex,
  ps2 : String,
  bare_continuation : Bool,
  text : String,
) -> Array[@lexer.Token] raise {
  let out : Array[@lexer.Token] = []
  let mut pos = 0
  let curcode = StringBuilder()
  let mut curlen = 0
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  let mut backslash_continuation = false
  fn flush(pos : Int, code : String, ins) raise {
    for t in @lexer.do_insertions(ins, inner.get_tokens_unprocessed(code)) {
      out.push({ ..t, index: pos + t.index, })
    }
  }

  for entry in pystr_lines(text) {
    let (mstart, full) = entry
    let mut line = full
    match shell_venv_re.match_at(line, 0) {
      Some(vm) => {
        insertions.push(
          (
            curlen,
            [
              pystr_itok(
                @token.generic_prompt.sub("VirtualEnv"),
                vm.group(1).unwrap(),
              ),
            ],
          ),
        )
        let ws = vm.group(2).unwrap_or("")
        if ws != "" {
          insertions.push((curlen, [pystr_itok(@token.text, ws)]))
        }
        line = line.unsafe_substring(start=vm.end(), end=line.length())
      }
      None => ()
    }
    match ps1.match_at(line, 0) {
      Some(m) => {
        if insertions.is_empty() {
          pos = mstart
        }
        insertions.push(
          (curlen, [pystr_itok(@token.generic_prompt, m.group(1).unwrap())]),
        )
        let code = m.group(2).unwrap_or("")
        curcode.write_string(code)
        curlen += code.length()
        backslash_continuation = curcode.to_string().has_suffix("\\\n")
      }
      None =>
        if backslash_continuation {
          if line.has_prefix(ps2) {
            insertions.push((curlen, [pystr_itok(@token.generic_prompt, ps2)]))
            let rest = line.unsafe_substring(
              start=ps2.length(),
              end=line.length(),
            )
            curcode.write_string(rest)
            curlen += rest.length()
          } else {
            curcode.write_string(line)
            curlen += line.length()
          }
          backslash_continuation = curcode.to_string().has_suffix("\\\n")
        } else if bare_continuation && line.has_prefix(ps2) {
          insertions.push((curlen, [pystr_itok(@token.generic_prompt, ps2)]))
          let rest = line.unsafe_substring(
            start=ps2.length(),
            end=line.length(),
          )
          curcode.write_string(rest)
          curlen += rest.length()
        } else {
          if !insertions.is_empty() {
            flush(pos, curcode.to_string(), insertions)
          }
          out.push({ index: mstart, ttype: @token.generic_output, value: line, })
          insertions = []
          curcode.reset()
          curlen = 0
        }
    }
  }
  if !insertions.is_empty() {
    flush(pos, curcode.to_string(), insertions)
  }
  out
}

///|
let bash_session_ps1_re : @regex.Regex = @lexer.re(
  "^((?:(?:\\[.*?\\])|(?:\\(\\S+\\))?(?:| |sh\\S*?|\\w+\\S+[@:]\\S+(?:\\s+\\S+)" +
  "?|\\[\\S+[@:][^\\n]+\\].+))\\s*[$#%❯]\\s*)(.*\\n?)",
)

///|
fn bash_session_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  shell_session_tokenize(
    bash_lexer(options=lx.options),
    bash_session_ps1_re,
    "> ",
    false,
    text,
  )
}

///|
let msdos_session_ps1_re : @regex.Regex = @lexer.re("^([^>]*>)(.*\\n?)")

///|
fn msdos_session_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  shell_session_tokenize(
    batch_lexer(options=lx.options),
    msdos_session_ps1_re,
    "More? ",
    false,
    text,
  )
}

///|
let tcsh_session_ps1_re : @regex.Regex = @lexer.re("^([^>]+>)(.*\\n?)")

///|
fn tcsh_session_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  shell_session_tokenize(
    tcsh_lexer(options=lx.options),
    tcsh_session_ps1_re,
    "? ",
    false,
    text,
  )
}

///|
let power_shell_session_ps1_re : @regex.Regex = @lexer.re(
  "^((?:\\[[^]]+\\]: )?PS[^>]*> ?)(.*\\n?)",
)

///|
fn power_shell_session_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  shell_session_tokenize(
    power_shell_lexer(options=lx.options),
    power_shell_session_ps1_re,
    "> ",
    true,
    text,
  )
}
