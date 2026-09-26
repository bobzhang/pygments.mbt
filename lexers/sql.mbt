// Hand-written parts of pygments/lexers/sql.py.
// pyhelper: sql.PsqlRegexLexer
// pydata: googlesql_identifiers = set(L.sql.googlesql_identifiers)

///|
let sql_language_re : @regex.Regex = @lexer.re(
  "\\s+LANGUAGE\\s+'?(\\w+)'?",
  flags=@regex.IGNORECASE,
)

///|
let sql_do_re : @regex.Regex = @lexer.re("\\bDO\\b", flags=@regex.IGNORECASE)

///|
/// `PostgresBase._get_lexer`: the lexer for a `LANGUAGE` name, if any.
fn postgres_get_lexer(lx : @lexer.Lexer, lang : String) -> @lexer.Lexer? {
  if lang.to_lower() == "sql" {
    return Some(lookup_lexer("postgresql", options=lx.options)) catch {
      _ => None
    }
  }
  let tries = [lang]
  if lang.has_prefix("pl") {
    tries.push(pystr_from(lang, 2))
  }
  if lang.has_suffix("u") {
    tries.push(@lexer.py_slice(lang, 0, -1))
  }
  if lang.has_prefix("pl") && lang.has_suffix("u") {
    tries.push(@lexer.py_slice(lang, 2, -1))
  }
  for name in tries {
    try lookup_lexer(name, options=lx.options) catch {
      _ => continue
    } noraise {
      l => return Some(l)
    }
  }
  None
}

///|
/// `language_callback`: lexes the content of a `$`-string with the lexer of
/// a nearby `LANGUAGE` clause (or PL/pgSQL inside a `DO` statement).
/// As in Python, the tokens of the embedded lexer are not re-offset.
fn sql_language_callback(ctx : @lexer.Ctx, m : @regex.Match) -> Unit raise {
  let text = ctx.text
  let lexer = ctx.lexer
  let after = @lexer.py_slice(
    text,
    m.end(),
    pystr_cp_advance(text, m.end(), 100),
  )
  let lx = match sql_language_re.match_at(after, 0) {
    Some(lm) => postgres_get_lexer(lexer, lm.group(1).unwrap_or(""))
    None => {
      let before = @lexer.py_slice(
        text,
        pystr_cp_retreat(text, m.start(), 100),
        m.start(),
      )
      match sql_language_re.find_all(before).last() {
        Some(lm) => postgres_get_lexer(lexer, lm.group(1).unwrap_or(""))
        None => {
          let before = @lexer.py_slice(
            text,
            pystr_cp_retreat(text, m.start(), 25),
            m.start(),
          )
          if sql_do_re.find_all(before).is_empty() {
            None
          } else {
            postgres_get_lexer(lexer, "plpgsql")
          }
        }
      }
    }
  }
  let g = (i : Int) => m.group(i).unwrap_or("")
  // 1 = $, 2 = delimiter, 3 = $
  ctx.emit(m.start(group=1), @token.string, g(1))
  ctx.emit(m.start(group=2), @token.string_delimiter, g(2))
  ctx.emit(m.start(group=3), @token.string, g(3))
  // 4 = string contents
  match lx {
    Some(l) =>
      for t in l.get_tokens_unprocessed(g(4)) {
        ctx.emit(t.index, t.ttype, t.value)
      }
    None => ctx.emit(m.start(group=4), @token.string, g(4))
  }
  // 5 = $, 6 = delimiter, 7 = $
  ctx.emit(m.start(group=5), @token.string, g(5))
  ctx.emit(m.start(group=6), @token.string_delimiter, g(6))
  ctx.emit(m.start(group=7), @token.string, g(7))
}

///|
fn postgres_callbacks() -> Map[String, @lexer.CallbackFn] {
  { "language_callback": (ctx, m, _) => sql_language_callback(ctx, m) }
}

///|
/// `PostgresBase.get_tokens_unprocessed` (keeps the full text for
/// `language_callback`, which reads it from the context).
fn postgres_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    postgres_lexer_def.force(),
    text,
    stack,
    callbacks=postgres_callbacks(),
  )
}

///|
fn pl_pgsql_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    pl_pgsql_lexer_def.force(),
    text,
    stack,
    callbacks=postgres_callbacks(),
  )
}

///|
fn psql_regex_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    psql_regex_lexer_def.force(),
    text,
    stack,
    callbacks=postgres_callbacks(),
  )
}

///|
let psql_prompt_re : @regex.Regex = @lexer.re(
  "^(\\S.*?)??[=\\-\\(\\$\\'\\\"][#>]",
)

///|
let psql_end_command_re : @regex.Regex = @lexer.re(";\\s*(--.*?)?$")

///|
let psql_command_re : @regex.Regex = @lexer.re("(\\s*)(\\\\.+?)(\\s+)$")

///|
let psql_message_re : @regex.Regex = @lexer.re(
  "((?:DEBUG|INFO|NOTICE|WARNING|ERROR|" +
  "FATAL|HINT|DETAIL|CONTEXT|LINE [0-9]+):)(.*?\\n)",
)

///|
/// `PostgresConsoleLexer.get_tokens_unprocessed`: alternates between a
/// command (prompts + SQL, until the end of the statement) and its output.
/// Offsets follow Python (output lines are reported at offset 0 or at their
/// offset within the line).
fn postgres_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  data : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let sql = psql_regex_lexer(options=lx.options)
  let lines = pystr_lines(data).map(e => e.1)
  let out : Array[@lexer.Token] = []
  let mut i = 0
  // prompt-output cycle
  while true {
    // consume the lines of the command: start with an optional prompt
    // and continue until the end of command is detected
    let mut curcode = ""
    let insertions : Array[(Int, Array[@lexer.Token])] = []
    while i < lines.length() {
      let line = lines[i]
      i += 1
      // a shell prompt in case of psql commandline example
      if line.has_prefix("$") && curcode == "" {
        let console = lookup_lexer("console", options=lx.options)
        out.append(console.get_tokens_unprocessed(line))
        break
      }
      // a psql prompt
      match psql_prompt_re.match_at(line, 0) {
        Some(mprompt) => {
          let p = mprompt.matched()
          insertions.push(
            (curcode.length(), [pystr_itok(@token.generic_prompt, p)]),
          )
          curcode = curcode + pystr_from(line, p.length())
        }
        None => curcode = curcode + line
      }
      // check if this is the end of the command
      if psql_command_re.match_at(curcode, 0) is Some(_) ||
        psql_end_command_re.search(curcode) is Some(_) {
        break
      }
    }
    // emit the combined stream of command and prompt(s)
    out.append(
      @lexer.do_insertions(insertions, sql.get_tokens_unprocessed(curcode)),
    )
    // emit the output lines
    let mut out_token = @token.generic_output
    let mut pushed_back = false
    while i < lines.length() {
      let line = lines[i]
      i += 1
      if psql_prompt_re.match_at(line, 0) is Some(_) {
        // push the line back to have it processed by the prompt
        i -= 1
        pushed_back = true
        break
      }
      match psql_message_re.match_at(line, 0) {
        Some(mmsg) => {
          let g1 = mmsg.group(1).unwrap_or("")
          if g1.has_prefix("ERROR") || g1.has_prefix("FATAL") {
            out_token = @token.generic_error
          }
          out.push({
            index: mmsg.start(group=1),
            ttype: @token.generic_strong,
            value: g1,
          })
          out.push({
            index: mmsg.start(group=2),
            ttype: out_token,
            value: mmsg.group(2).unwrap_or(""),
          })
        }
        None => out.push({ index: 0, ttype: out_token, value: line, })
      }
    }
    if !pushed_back {
      break
    }
  }
  out
}

///|
let sqlite_prompt_re : @regex.Regex = @lexer.re("^(?:sqlite|   ...)>(?= )")

///|
/// `SqliteConsoleLexer.get_tokens_unprocessed`.
fn sqlite_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  data : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let sql = sql_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(data) {
    let (start, line) = entry
    if sqlite_prompt_re.match_at(line, 0) is Some(_) {
      insertions.push(
        (
          curcode.length(),
          [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, 7))],
        ),
      )
      insertions.push((curcode.length(), [pystr_itok(@token.whitespace, " ")]))
      curcode = curcode + pystr_from(line, 8)
    } else {
      if curcode != "" {
        out.append(
          @lexer.do_insertions(insertions, sql.get_tokens_unprocessed(curcode)),
        )
        curcode = ""
        insertions = []
      }
      let ttype = if line.has_prefix("SQL error: ") {
        @token.generic_traceback
      } else {
        @token.generic_output
      }
      out.push({ index: start, ttype, value: line, })
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, sql.get_tokens_unprocessed(curcode)),
    )
  }
  out
}

///|
/// `SqlLexer.analyse_text` is declared with a `self` parameter and returns
/// `None`: always 0.
fn sql_lexer_analyse(_text : String) -> Double {
  0.0
}

///|
let sql_name_between_bracket_re : @regex.Regex = @lexer.re(
  "\\[[a-zA-Z_]\\w*\\]",
)

///|
let sql_name_between_backtick_re : @regex.Regex = @lexer.re("`[a-zA-Z_]\\w*`")

///|
let tsql_go_re : @regex.Regex = @lexer.re("\\bgo\\b", flags=@regex.IGNORECASE)

///|
let tsql_declare_re : @regex.Regex = @lexer.re(
  "\\bdeclare\\s+@",
  flags=@regex.IGNORECASE,
)

///|
let tsql_variable_re : @regex.Regex = @lexer.re("@[a-zA-Z_]\\w*\\b")

///|
fn sql_count_matches(re : @regex.Regex, text : String) -> Int {
  (re.find_all(text) catch { _ => [] }).length()
}

///|
fn transact_sql_lexer_analyse(text : String) -> Double {
  let mut rating = 0.0
  if @lexer.search(tsql_declare_re, text) {
    // found T-SQL variable declaration
    rating = 1.0
  } else {
    let backtick = sql_count_matches(sql_name_between_backtick_re, text)
    let bracket = sql_count_matches(sql_name_between_bracket_re, text)
    // names using backticks or brackets must exist, as otherwise both are 0
    let dialect_name_count = backtick + bracket
    if dialect_name_count >= 1 && bracket >= 2 * backtick {
      rating += 0.5
    } else if bracket > backtick {
      rating += 0.2
    } else if bracket > 0 {
      rating += 0.1
    }
    if @lexer.search(tsql_variable_re, text) {
      rating += 0.1
    }
    if @lexer.search(tsql_go_re, text) {
      rating += 0.1
    }
  }
  rating
}

///|
fn my_sql_lexer_analyse(text : String) -> Double {
  let mut rating = 0.0
  let backtick = sql_count_matches(sql_name_between_backtick_re, text)
  let bracket = sql_count_matches(sql_name_between_bracket_re, text)
  let dialect_name_count = backtick + bracket
  if dialect_name_count >= 1 && backtick >= 2 * bracket {
    rating += 0.5
  } else if backtick > bracket {
    rating += 0.2
  } else if backtick > 0 {
    rating += 0.1
  }
  rating
}

///|
fn google_sql_lexer_analyse(text : String) -> Double {
  let mut count = 0
  for t in @lexer.split_whitespace(text) {
    if googlesql_identifiers.contains(t) {
      count += 1
    }
  }
  0.001 * count.to_double()
}
