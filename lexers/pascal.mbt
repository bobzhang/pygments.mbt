// Hand-written parts of pygments/lexers/pascal.py.
// pydata: delphi_turbo_pascal_keywords = L.pascal.DelphiLexer.TURBO_PASCAL_KEYWORDS
// pydata: delphi_delphi_keywords = L.pascal.DelphiLexer.DELPHI_KEYWORDS
// pydata: delphi_free_pascal_keywords = L.pascal.DelphiLexer.FREE_PASCAL_KEYWORDS
// pydata: delphi_block_keywords = L.pascal.DelphiLexer.BLOCK_KEYWORDS
// pydata: delphi_function_modifiers = L.pascal.DelphiLexer.FUNCTION_MODIFIERS
// pydata: delphi_directives = L.pascal.DelphiLexer.DIRECTIVES
// pydata: delphi_builtin_types = L.pascal.DelphiLexer.BUILTIN_TYPES
// pydata: delphi_builtin_units = L.pascal.DelphiLexer.BUILTIN_UNITS
// pydata: delphi_builtin_unit_names = list(L.pascal.DelphiLexer.BUILTIN_UNITS)
// pydata: delphi_asm_registers = L.pascal.DelphiLexer.ASM_REGISTERS
// pydata: delphi_asm_instructions = L.pascal.DelphiLexer.ASM_INSTRUCTIONS
// pydata: delphi_portugol_keywords = L.pascal.DelphiLexer.PORTUGOL_KEYWORDS
// pydata: delphi_portugol_builtin_types = L.pascal.DelphiLexer.PORTUGOL_BUILTIN_TYPES

///|
/// Errors of `DelphiLexer`: `EndOfText` is raised by `DelphiScanner` when
/// matching at the end of the text (Python's `pygments.scanner.EndOfText`);
/// `UnknownUnit` for an entry of the `units` option that is not a key of
/// `BUILTIN_UNITS` (Python raises `KeyError`).
priv suberror DelphiError {
  EndOfText
  UnknownUnit(String)
} derive(Debug)

///|
/// Port of `pygments.scanner.Scanner` (flags `DOTALL | MULTILINE |
/// IGNORECASE`, as used by `DelphiLexer`).
priv struct DelphiScanner {
  text : String
  mut pos : Int
  mut start_pos : Int
  mut matched : String
}

///|
fn DelphiScanner::eos(self : DelphiScanner) -> Bool {
  self.pos >= self.text.length()
}

///|
/// `Scanner.test`: whether `re` matches at the current position.
fn DelphiScanner::lookahead(
  self : DelphiScanner,
  re : @regex.Regex,
) -> Bool raise {
  if self.eos() {
    raise EndOfText
  }
  re.match_at(self.text, self.pos, budget=@lexer.budget()) is Some(_)
}

///|
/// `Scanner.scan`: on success moves past the match and records it.
fn DelphiScanner::scan(self : DelphiScanner, re : @regex.Regex) -> Bool raise {
  if self.eos() {
    raise EndOfText
  }
  match re.match_at(self.text, self.pos, budget=@lexer.budget()) {
    None => false
    Some(m) => {
      self.start_pos = m.start()
      self.pos = m.end()
      self.matched = m.matched()
      true
    }
  }
}

///|
fn delphi_re(pattern : String) -> @regex.Regex {
  @lexer.re(pattern, flags=@regex.DOTALL | @regex.MULTILINE | @regex.IGNORECASE)
}

///|
let delphi_ws_re : @regex.Regex = delphi_re("\\s+")

///|
let delphi_comment_re : @regex.Regex = delphi_re("\\{.*?\\}|\\(\\*.*?\\*\\)")

///|
let delphi_line_comment_re : @regex.Regex = delphi_re("//.*?$")

///|
let delphi_portugol_operator_re : @regex.Regex = delphi_re(
  "(<\\-)|(>=)|(<=)|%|<|>|-|\\+|\\*|\\=|(<>)|\\/|\\.|:|,",
)

///|
let delphi_operator_re : @regex.Regex = delphi_re("[-+*\\/=<>:;,.@\\^]")

///|
let delphi_punctuation_re : @regex.Regex = delphi_re("[\\(\\)\\[\\]]+")

///|
let delphi_name_re : @regex.Regex = delphi_re("[A-Za-z_][A-Za-z_0-9]*")

///|
let delphi_dot_re : @regex.Regex = delphi_re("\\s*\\.\\s*")

///|
let delphi_dquote_re : @regex.Regex = delphi_re("\\\"")

///|
let delphi_squote_re : @regex.Regex = delphi_re("'")

///|
let delphi_char_re : @regex.Regex = delphi_re("\\#(\\d+|\\$[0-9A-Fa-f]+)")

///|
let delphi_hex_re : @regex.Regex = delphi_re("\\$[0-9A-Fa-f]+")

///|
let delphi_integer_re : @regex.Regex = delphi_re("\\d+(?![eE]|\\.[^.])")

///|
let delphi_float_re : @regex.Regex = delphi_re(
  "\\d+(\\.\\d+([eE][+-]?\\d+)?|[eE][+-]?\\d+)",
)

///|
let delphi_any_char_re : @regex.Regex = delphi_re(".")

///|
let delphi_escaped_quote_re : @regex.Regex = delphi_re("''")

///|
let delphi_dstring_body_re : @regex.Regex = delphi_re("[^\\\"]*")

///|
let delphi_sstring_body_re : @regex.Regex = delphi_re("[^']*")

///|
let delphi_asm_end_re : @regex.Regex = delphi_re("end")

///|
let delphi_asm_label_re : @regex.Regex = delphi_re("@@[A-Za-z_][A-Za-z_0-9]*")

///|
let delphi_asm_operator_re : @regex.Regex = delphi_re("[-+*\\/=<>:;,.@\\^]+")

///|
/// `DelphiLexer.__init__`: the keyword and builtin sets selected by the
/// `portugol`, `turbopascal`, `delphi`, `freepascal` and `units` options.
fn delphi_sets(
  options : @lexer.Options,
  portugol : Bool,
) -> (@set.Set[String], @set.Set[String]) raise {
  let keywords : @set.Set[String] = @set.Set([])
  let builtins : @set.Set[String] = @set.Set([])
  if portugol {
    delphi_portugol_keywords.each(k => keywords.add(k))
    delphi_portugol_builtin_types.each(b => builtins.add(b))
  } else {
    if @lexer.get_bool_opt(options, "turbopascal", true) {
      delphi_turbo_pascal_keywords.each(k => keywords.add(k))
    }
    if @lexer.get_bool_opt(options, "delphi", true) {
      delphi_delphi_keywords.each(k => keywords.add(k))
    }
    if @lexer.get_bool_opt(options, "freepascal", true) {
      delphi_free_pascal_keywords.each(k => keywords.add(k))
    }
    for unit in @lexer.get_list_opt(options, "units", delphi_builtin_unit_names) {
      match delphi_builtin_units.get(unit) {
        Some(names) => names.each(b => builtins.add(b))
        None => raise UnknownUnit(unit)
      }
    }
  }
  (keywords, builtins)
}

///|
fn has_non_space(s : String) -> Bool {
  s.iter().any(c => !@lexer.is_space(c))
}

///|
/// `DelphiLexer.get_tokens_unprocessed`: a hand-written scanner keeping
/// track of function, property, label and `asm` blocks.
fn delphi_scan(
  text : String,
  portugol : Bool,
  keywords : @set.Set[String],
  builtins : @set.Set[String],
) -> Array[@lexer.Token] raise {
  let out : Array[@lexer.Token] = []
  let scanner : DelphiScanner = { text, pos: 0, start_pos: 0, matched: "", }
  let stack = ["initial"]
  let mut in_function_block = false
  let mut in_property_block = false
  let mut was_dot = false
  let mut next_token_is_function = false
  let mut next_token_is_property = false
  let mut collect_labels = false
  let mut block_labels : @set.Set[String] = @set.Set([])
  let brace_balance = [0, 0]
  while !scanner.eos() {
    let mut token = @token.error
    let top = stack[stack.length() - 1]
    if top == "initial" {
      if scanner.scan(delphi_ws_re) {
        token = @token.whitespace
      } else if !portugol && scanner.scan(delphi_comment_re) {
        token = if scanner.matched.has_prefix("$") {
          @token.comment_preproc
        } else {
          @token.comment_multiline
        }
      } else if scanner.scan(delphi_line_comment_re) {
        token = @token.comment_single
      } else if portugol && scanner.scan(delphi_portugol_operator_re) {
        token = @token.operator
      } else if !portugol && scanner.scan(delphi_operator_re) {
        token = @token.operator
        // stop label highlighting on next ";"
        if collect_labels && scanner.matched == ";" {
          collect_labels = false
        }
      } else if scanner.scan(delphi_punctuation_re) {
        token = @token.punctuation
        // abort function naming ``foo = Function(...)``
        next_token_is_function = false
        // count the open braces to find the end of the modifier context
        if in_function_block || in_property_block {
          match scanner.matched {
            "(" => brace_balance[0] += 1
            ")" => brace_balance[0] -= 1
            "[" => brace_balance[1] += 1
            "]" => brace_balance[1] -= 1
            _ => ()
          }
        }
      } else if scanner.scan(delphi_name_re) {
        let lowercase_name = scanner.matched.to_lower()
        if lowercase_name == "result" {
          token = @token.name_builtin_pseudo
        } else if keywords.contains(lowercase_name) {
          token = @token.keyword
          if portugol {
            if lowercase_name == "funcao" || lowercase_name == "procedimento" {
              in_function_block = true
              next_token_is_function = true
            }
          } else {
            // a block ending keyword (with balanced parentheses) ends the
            // current block context
            if (in_function_block || in_property_block) &&
              delphi_block_keywords.contains(lowercase_name) &&
              brace_balance[0] <= 0 &&
              brace_balance[1] <= 0 {
              in_function_block = false
              in_property_block = false
              brace_balance[0] = 0
              brace_balance[1] = 0
              block_labels = @set.Set([])
            }
            match lowercase_name {
              "label" | "goto" => collect_labels = true
              "asm" => stack.push("asm")
              "property" => {
                in_property_block = true
                next_token_is_property = true
              }
              "procedure"
              | "operator"
              | "function"
              | "constructor"
              | "destructor" => {
                in_function_block = true
                next_token_is_function = true
              }
              _ => ()
            }
          }
        } else if !portugol &&
          in_function_block &&
          delphi_function_modifiers.contains(lowercase_name) {
          token = @token.keyword_pseudo
        } else if !portugol &&
          in_property_block &&
          (lowercase_name == "read" || lowercase_name == "write") {
          token = @token.keyword_pseudo
          next_token_is_function = true
        } else if next_token_is_function {
          // a following dot means this is a class name and the part after
          // the dot the function name
          if !portugol && scanner.lookahead(delphi_dot_re) {
            token = @token.name_class
          } else {
            token = @token.name_function
            next_token_is_function = false
            if portugol {
              block_labels.add(scanner.matched.to_lower())
            }
          }
        } else if !portugol && next_token_is_property {
          token = @token.name_property
          next_token_is_property = false
        } else if !portugol && collect_labels {
          token = @token.name_label
          block_labels.add(scanner.matched.to_lower())
        } else if block_labels.contains(lowercase_name) {
          token = @token.name_label
        } else if portugol &&
          delphi_portugol_builtin_types.contains(lowercase_name) {
          token = @token.keyword_type
        } else if !portugol && delphi_builtin_types.contains(lowercase_name) {
          token = @token.keyword_type
        } else if !portugol && delphi_directives.contains(lowercase_name) {
          token = @token.keyword_pseudo
        } else if !portugol && !was_dot && builtins.contains(lowercase_name) {
          // builtins are just builtins if the token before isn't a dot
          token = @token.name_builtin
        } else {
          token = @token.name
        }
      } else if portugol && scanner.scan(delphi_dquote_re) {
        token = @token.string
        stack.push("string")
      } else if !portugol && scanner.scan(delphi_squote_re) {
        token = @token.string
        stack.push("string")
      } else if !portugol && scanner.scan(delphi_char_re) {
        token = @token.string_char
      } else if !portugol && scanner.scan(delphi_hex_re) {
        token = @token.number_hex
      } else if scanner.scan(delphi_integer_re) {
        token = @token.number_integer
      } else if scanner.scan(delphi_float_re) {
        token = @token.number_float
      } else {
        // if the stack depth is deeper than once, pop
        if stack.length() > 1 {
          ignore(stack.pop())
        }
        ignore(scanner.scan(delphi_any_char_re))
      }
    } else if top == "string" {
      let quote_re = if portugol { delphi_dquote_re } else { delphi_squote_re }
      let body_re = if portugol {
        delphi_dstring_body_re
      } else {
        delphi_sstring_body_re
      }
      if scanner.scan(delphi_escaped_quote_re) {
        token = @token.string_escape
      } else if scanner.scan(quote_re) {
        token = @token.string
        ignore(stack.pop())
      } else if scanner.scan(body_re) {
        token = @token.string
      } else {
        ignore(scanner.scan(delphi_any_char_re))
        ignore(stack.pop())
      }
    } else if !portugol && top == "asm" {
      if scanner.scan(delphi_ws_re) {
        token = @token.whitespace
      } else if scanner.scan(delphi_asm_end_re) {
        token = @token.keyword
        ignore(stack.pop())
      } else if scanner.scan(delphi_comment_re) {
        token = if scanner.matched.has_prefix("$") {
          @token.comment_preproc
        } else {
          @token.comment_multiline
        }
      } else if scanner.scan(delphi_line_comment_re) {
        token = @token.comment_single
      } else if scanner.scan(delphi_squote_re) {
        token = @token.string
        stack.push("string")
      } else if scanner.scan(delphi_asm_label_re) {
        token = @token.name_label
      } else if scanner.scan(delphi_name_re) {
        let lowercase_name = scanner.matched.to_lower()
        token = if delphi_asm_instructions.contains(lowercase_name) {
          @token.keyword
        } else if delphi_asm_registers.contains(lowercase_name) {
          @token.name_builtin
        } else {
          @token.name
        }
      } else if scanner.scan(delphi_asm_operator_re) {
        token = @token.operator
      } else if scanner.scan(delphi_punctuation_re) {
        token = @token.punctuation
      } else if scanner.scan(delphi_hex_re) {
        token = @token.number_hex
      } else if scanner.scan(delphi_integer_re) {
        token = @token.number_integer
      } else if scanner.scan(delphi_float_re) {
        token = @token.number_float
      } else {
        ignore(scanner.scan(delphi_any_char_re))
        ignore(stack.pop())
      }
    }
    // save the dot!!!11
    if !portugol && has_non_space(scanner.matched) {
      was_dot = scanner.matched == "."
    }
    out.push({ index: scanner.start_pos, ttype: token, value: scanner.matched, })
  }
  out
}

///|
fn delphi_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let portugol = @lexer.get_bool_opt(lx.options, "portugol", false)
  let (keywords, builtins) = delphi_sets(lx.options, portugol)
  delphi_scan(text, portugol, keywords, builtins)
}

///|
/// `PortugolLexer`: a `DelphiLexer` with the `portugol` option set.
fn portugol_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let (keywords, builtins) = delphi_sets(lx.options, true)
  delphi_scan(text, true, keywords, builtins)
}
