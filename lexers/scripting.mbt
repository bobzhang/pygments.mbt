// Hand-written parts of pygments/lexers/scripting.py.
// pydata: lua_builtin_modules = L._lua_builtins.MODULES
// pydata: luau_builtins = L._luau_builtins.LUAU_BUILTINS
// pydata: roblox_builtins = L._luau_builtins.ROBLOX_BUILTINS

///|
/// `LuaLexer.__init__` + `get_tokens_unprocessed`: builtins of disabled
/// modules (or all of them without `func_name_highlighting`) become `Name`.
fn lua_filter_builtins(
  lx : @lexer.Lexer,
  tokens : Array[@lexer.Token],
) -> Array[@lexer.Token] raise {
  let func_name_highlighting = @lexer.get_bool_opt(
    lx.options,
    "func_name_highlighting",
    true,
  )
  let disabled_modules = @lexer.get_list_opt(lx.options, "disabled_modules", [])
  let functions : @set.Set[String] = @set.Set([])
  if func_name_highlighting {
    for mod_, funcs in lua_builtin_modules {
      if !disabled_modules.contains(mod_) {
        for f in funcs {
          functions.add(f)
        }
      }
    }
  }
  let out : Array[@lexer.Token] = []
  for t in tokens {
    if t.ttype == @token.name_builtin && !functions.contains(t.value) {
      if t.value.contains(".") {
        let parts = pystr_split(t.value, ".")
        guard parts is [a, b] else { fail("too many values to unpack") }
        out.push({ index: t.index, ttype: @token.name, value: a, })
        out.push({
          index: t.index + a.length(),
          ttype: @token.punctuation,
          value: ".",
        })
        out.push({
          index: t.index + a.length() + 1,
          ttype: @token.name,
          value: b,
        })
      } else {
        out.push({ ..t, ttype: @token.name, })
      }
      continue
    }
    out.push(t)
  }
  out
}

///|
fn lua_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  lua_filter_builtins(
    lx,
    @lexer.run_regex(lx, lua_lexer_def.force(), text, stack),
  )
}

///|
fn moon_script_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  lua_filter_builtins(
    lx,
    @lexer.run_regex(lx, moon_script_lexer_def.force(), text, stack),
  ).map(t => {
    if t.ttype == @token.punctuation && t.value == "." {
      { ..t, ttype: @token.operator, }
    } else {
      t
    }
  })
}

///|
fn luau_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let include_luau = @lexer.get_bool_opt(
    lx.options,
    "include_luau_builtins",
    true,
  )
  let include_roblox = @lexer.get_bool_opt(
    lx.options,
    "include_roblox_builtins",
    false,
  )
  let additional = @lexer.get_list_opt(lx.options, "additional_builtins", [])
  let disabled = @lexer.get_list_opt(lx.options, "disabled_builtins", [])
  let builtins : @set.Set[String] = @set.Set([])
  for b in additional {
    builtins.add(b)
  }
  if include_luau {
    for b in luau_builtins {
      builtins.add(b)
    }
  }
  if include_roblox {
    for b in roblox_builtins {
      builtins.add(b)
    }
  }
  for b in disabled {
    builtins.remove(b)
  }
  let out : Array[@lexer.Token] = []
  for t in @lexer.run_regex(lx, luau_lexer_def.force(), text, stack) {
    let token = t.ttype
    if token == @token.name || token == @token.name_other {
      let index = t.index
      let split_value = pystr_split(t.value, ".")
      let complete_value : Array[String] = []
      let mut new_index = index
      for position = split_value.length(); position > 0; position = position - 1 {
        let potential = split_value[0:position].join(".")
        if builtins.contains(potential) {
          out.push({ index, ttype: @token.name_builtin, value: potential, })
          new_index += potential.length()
          if !complete_value.is_empty() {
            out.push({
              index: new_index,
              ttype: @token.punctuation,
              value: ".",
            })
            new_index += 1
          }
          break
        }
        complete_value.insert(0, split_value[position - 1])
      }
      for position, substring in complete_value {
        if position + 1 == complete_value.length() {
          out.push({
            index: new_index,
            ttype: if token == @token.name {
              @token.name_variable
            } else {
              @token.name_function
            },
            value: substring,
          })
          continue
        }
        out.push({
          index: new_index,
          ttype: @token.name_variable,
          value: substring,
        })
        new_index += substring.length()
        out.push({ index: new_index, ttype: @token.punctuation, value: ".", })
        new_index += 1
      }
      continue
    }
    out.push(t)
  }
  out
}

///|
let rexx_header_re : @regex.Regex = @lexer.re(
  "/\\*\\**\\s*rexx",
  flags=@regex.IGNORECASE,
)

///|
let rexx_patterns_and_weights : Array[(@regex.Regex, Double)] = [
  (@lexer.re("^\\s*address\\s+command\\b", flags=@regex.MULTILINE), 0.2),
  (@lexer.re("^\\s*address\\s+", flags=@regex.MULTILINE), 0.05),
  (@lexer.re("^\\s*do\\s+while\\b", flags=@regex.MULTILINE), 0.1),
  (@lexer.re("\\belse\\s+do\\s*$", flags=@regex.MULTILINE), 0.1),
  (@lexer.re("^\\s*if\\b.+\\bthen\\s+do\\s*$", flags=@regex.MULTILINE), 0.1),
  (
    @lexer.re(
      "^\\s*([a-z_]\\w*)(\\s*)(:)(\\s*)(procedure)\\b",
      flags=@regex.MULTILINE,
    ),
    0.5,
  ),
  (
    @lexer.re(
      "^\\s*parse\\s+(upper\\s+)?(arg|value)\\b",
      flags=@regex.MULTILINE,
    ),
    0.2,
  ),
]

///|
fn rexx_lexer_analyse(text : String) -> Double {
  if @lexer.search(rexx_header_re, text) {
    return 1.0
  }
  if !text.has_prefix("/*") {
    return 0.0
  }
  let lower = text.to_lower()
  let mut result = 0.0
  for pw in rexx_patterns_and_weights {
    if @lexer.search(pw.0, lower) {
      result += pw.1
    }
  }
  result += 0.01
  if result < 1.0 {
    result
  } else {
    1.0
  }
}

///|
let hybris_method_re : @regex.Regex = @lexer.re(
  "\\b(?:public|private)\\s+method\\b",
)

///|
fn hybris_lexer_analyse(text : String) -> Double {
  if @lexer.search(hybris_method_re, text) {
    0.01
  } else {
    0.0
  }
}

///|
let easytrieve_comment_line_re : @regex.Regex = @lexer.re("^\\s*\\*")

///|
let easytrieve_macro_header_re : @regex.Regex = @lexer.re("^\\s*MACRO")

///|
fn easytrieve_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  let lines = pystr_split(text, "\n")
  let mut has_end_proc = false
  let mut has_header_comment = false
  let mut has_file = false
  let mut has_job = false
  let mut has_proc = false
  let mut has_parm = false
  let mut has_report = false
  let is_empty_line = (line : String) => pystr_strip(line) == ""
  let mut first = 0
  while first < lines.length() &&
        (
          is_empty_line(lines[first]) ||
          @lexer.matches(easytrieve_comment_line_re, lines[first])
        ) {
    if !is_empty_line(lines[first]) {
      has_header_comment = true
    }
    first += 1
  }
  if first >= lines.length() {
    // Python raises IndexError on `lines[0]`
    return 0.0
  }
  if @lexer.matches(easytrieve_macro_header_re, lines[first]) {
    result = 0.4
    if has_header_comment {
      result += 0.4
    }
  } else {
    for line in lines[first:] {
      let words = @lexer.split_whitespace(line)
      if words.length() >= 2 {
        let first_word = words[0]
        if !has_report {
          if !has_job {
            if !has_file {
              if !has_parm {
                if first_word == "PARM" {
                  has_parm = true
                }
              }
              if first_word == "FILE" {
                has_file = true
              }
            }
            if first_word == "JOB" {
              has_job = true
            }
          } else if first_word == "PROC" {
            has_proc = true
          } else if first_word == "END-PROC" {
            has_end_proc = true
          } else if first_word == "REPORT" {
            has_report = true
          }
        }
      }
    }
    if has_job && has_proc == has_end_proc {
      if has_header_comment {
        result += 0.1
      }
      if has_parm {
        if has_proc {
          result += 0.8
        } else {
          result += 0.5
        }
      } else {
        result += 0.11
        if has_parm {
          result += 0.2
        }
        if has_file {
          result += 0.01
        }
        if has_report {
          result += 0.01
        }
      }
    }
  }
  if result < 0.0 || result > 1.0 {
    // Python's `assert` fails
    return 0.0
  }
  result
}

///|
let jcl_job_header_re : @regex.Regex = @lexer.re(
  "^//[a-z#$@][a-z0-9#$@]{0,7}\\s+job(\\s+.*)?$",
  flags=@regex.IGNORECASE,
)

///|
fn jcl_lexer_analyse(text : String) -> Double {
  let lines = pystr_split(text, "\n")
  if lines.length() > 0 && @lexer.matches(jcl_job_header_re, lines[0]) {
    1.0
  } else {
    0.0
  }
}
