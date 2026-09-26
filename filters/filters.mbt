///|
/// Raised by the `raiseonerror` filter on an `Error` token (Python's
/// `ErrorToken`; the `excclass` option cannot be expressed as a string
/// option and is not supported).
pub suberror ErrorToken {
  ErrorToken(String)
} derive(Debug)

///|
/// Python's `CodeTagFilter` (`codetagify`): highlights special code tags
/// (`XXX`, `TODO`, `FIXME`, `BUG`, `NOTE`, or the `codetags` option) in
/// comments and docstrings as `Comment.Special`.
pub fn code_tag_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  let tags = @lexer.get_list_opt(options, "codetags", [
    "XXX", "TODO", "FIXME", "BUG", "NOTE",
  ])
  let alts = tags.filter(t => t != "").map(re_escape).join("|")
  let regex = @regex.compile("\\b(\{alts})\\b")
  {
    name: "codetagify",
    apply: fn(_, stream) raise {
      let out = []
      for tok in stream {
        let (ttype, value) = tok
        if ttype.is_subtype_of(@token.string_doc) ||
          (
            ttype.is_subtype_of(@token.comment) &&
            !ttype.is_subtype_of(@token.comment_preproc)
          ) {
          replace_special(out, ttype, value, regex, @token.comment_special)
        } else {
          out.push(tok)
        }
      }
      out
    },
  }
}

///|
/// Python's `SymbolFilter` (`symbols`): converts mathematical symbols such
/// as `\<longrightarrow>` (Isabelle, the default `lang`) or `\longrightarrow`
/// (`lang=latex`) into Unicode characters.
pub fn symbol_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  let lang = @lexer.get_choice_opt(
    options,
    "lang",
    ["isabelle", "latex"],
    "isabelle",
  )
  let symbols = if lang == "latex" { latex_symbols } else { isabelle_symbols }
  {
    name: "symbols",
    apply: fn(_, stream) {
      stream.map(tok => {
        match symbols.get(tok.1) {
          Some(v) => (tok.0, v)
          None => tok
        }
      })
    },
  }
}

///|
/// Python's `KeywordCaseFilter` (`keywordcase`): changes the case of
/// keywords (`case` option: `lower` (default), `upper` or `capitalize`).
pub fn keyword_case_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  let case = @lexer.get_choice_opt(
    options,
    "case",
    ["lower", "upper", "capitalize"],
    "lower",
  )
  let convert : (String) -> String = match case {
    "upper" => @pystr.upper
    "capitalize" => @pystr.capitalize
    _ => @pystr.lower
  }
  {
    name: "keywordcase",
    apply: fn(_, stream) {
      stream.map(tok => {
        if tok.0.is_subtype_of(@token.keyword) {
          (tok.0, convert(tok.1))
        } else {
          tok
        }
      })
    },
  }
}

///|
/// Python's `NameHighlightFilter` (`highlight`): gives the `Name` tokens
/// whose text is in `names` the type `tokentype` (default `Name.Function`).
pub fn name_highlight_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter {
  let names = @lexer.get_list_opt(options, "names", [])
  let tokentype = match options.get("tokentype") {
    Some(t) if t != "" => @token.from_string(t)
    _ => @token.name_function
  }
  {
    name: "highlight",
    apply: fn(_, stream) {
      stream.map(tok => {
        if tok.0.is_subtype_of(@token.name) && names.contains(tok.1) {
          (tokentype, tok.1)
        } else {
          tok
        }
      })
    },
  }
}

///|
/// Python's `RaiseOnErrorTokenFilter` (`raiseonerror`): raises `ErrorToken`
/// on the first `Error` token.
pub fn raise_on_error_token_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter {
  ignore(options)
  {
    name: "raiseonerror",
    apply: fn(_, stream) raise {
      for tok in stream {
        if tok.0 == @token.error {
          raise ErrorToken(tok.1)
        }
      }
      stream
    },
  }
}

///|
/// One of the `spaces`/`tabs`/`newlines` options of the whitespace filter:
/// a one-character string is used as is, any other non-empty value selects
/// the default (Python's `opt and default or ''`).
fn whitespace_opt(
  options : @lexer.Options,
  name : String,
  default : String,
) -> String {
  match options.get(name) {
    None => ""
    Some(v) if v.char_length() == 1 => v
    Some("") => ""
    Some(_) => default
  }
}

///|
/// Python's `VisibleWhitespaceFilter` (`whitespace`): makes spaces, tabs and
/// newlines visible by replacing them with `·`, `»` and `¶` (or the
/// characters given as options).
pub fn visible_whitespace_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  let spaces = whitespace_opt(options, "spaces", "·")
  let mut tabs = whitespace_opt(options, "tabs", "»")
  let mut newlines = whitespace_opt(options, "newlines", "¶")
  let tabsize = @lexer.get_int_opt(options, "tabsize", 8)
  if tabs != "" {
    tabs = tabs + (if tabsize > 1 { " ".repeat(tabsize - 1) } else { "" })
  }
  if newlines != "" {
    newlines = newlines + "\n"
  }
  let wstt = @lexer.get_bool_opt(options, "wstokentype", true)
  let tabs = tabs
  let newlines = newlines
  {
    name: "whitespace",
    apply: fn(_, stream) raise {
      if wstt {
        let sp = if spaces == "" { " " } else { spaces }
        let tb = if tabs == "" { "\t" } else { tabs }
        let nl = if newlines == "" { "\n" } else { newlines }
        let regex = @regex.compile("\\s")
        let replace = (ws : String) => {
          match ws {
            " " => sp
            "\t" => tb
            "\n" => nl
            _ => ws
          }
        }
        let out = []
        for tok in stream {
          replace_special(out, tok.0, tok.1, regex, @token.whitespace, replace~)
        }
        out
      } else {
        stream.map(tok => {
          let mut v = tok.1
          if spaces != "" {
            v = v.replace_all(old=" ", new=spaces)
          }
          if tabs != "" {
            v = v.replace_all(old="\t", new=tabs)
          }
          if newlines != "" {
            v = v.replace_all(old="\n", new=newlines)
          }
          (tok.0, v)
        })
      }
    },
  }
}

///|
/// Python's `GobbleFilter` (`gobble`): removes the first `n` characters of
/// every line.
pub fn gobble_filter(
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  let n = @lexer.get_int_opt(options, "n", 0)
  // (rest of `value` after dropping `left` code points, characters still to drop)
  fn gobble(value : String, left : Int) -> (String, Int) {
    let len = value.char_length()
    if left < len {
      (@pystr.slice(value, left), 0)
    } else {
      ("", left - len)
    }
  }

  {
    name: "gobble",
    apply: fn(_, stream) {
      let out = []
      let mut left = n
      for tok in stream {
        let parts = @pystr.split(tok.1, "\n")
        let (first, l) = gobble(parts[0], left)
        parts[0] = first
        left = l
        for i in 1..<parts.length() {
          let (p, l) = gobble(parts[i], n)
          parts[i] = p
          left = l
        }
        let value = parts.join("\n")
        if value != "" {
          out.push((tok.0, value))
        }
      }
      out
    },
  }
}

///|
/// Python's `TokenMergeFilter` (`tokenmerge`): merges consecutive tokens of
/// the same type.
pub fn token_merge_filter(options? : @lexer.Options = Map([])) -> @lexer.Filter {
  ignore(options)
  {
    name: "tokenmerge",
    apply: fn(_, stream) {
      let out : TokenStream = []
      for tok in stream {
        if out.length() > 0 && out[out.length() - 1].0 == tok.0 {
          let last = out[out.length() - 1]
          out[out.length() - 1] = (last.0, last.1 + tok.1)
        } else {
          out.push(tok)
        }
      }
      out
    },
  }
}
