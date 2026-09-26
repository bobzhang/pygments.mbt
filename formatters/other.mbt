///|
/// Metadata of Python's `NullFormatter`.
pub let null_info : FormatterInfo = {
  class_name: "NullFormatter",
  name: "Text only",
  aliases: ["text", "null"],
  filenames: ["*.txt"],
  description: "Output the text unchanged without any formatting.",
}

///|
/// Metadata of Python's `RawTokenFormatter`.
pub let raw_token_info : FormatterInfo = {
  class_name: "RawTokenFormatter",
  name: "Raw tokens",
  aliases: ["raw", "tokens"],
  filenames: ["*.raw"],
  description: "Format tokens as a raw representation for storing token streams.",
}

///|
/// Metadata of Python's `TestcaseFormatter`.
pub let testcase_info : FormatterInfo = {
  class_name: "TestcaseFormatter",
  name: "Testcase",
  aliases: ["testcase"],
  filenames: [],
  description: "Format tokens as appropriate for a new testcase.",
}

///|
/// Python's `NullFormatter`: the token texts, concatenated.
pub fn null_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  Formatter::new(null_info, base, tokens => {
    let buf = StringBuilder()
    for tok in tokens {
      buf.write_string(tok.1)
    }
    buf.to_string()
  })
}

///|
/// Python's `RawTokenFormatter`: one `Token.Type<TAB>'text'` line per token
/// (Python's `b"%r\t%r\n"`, i.e. ASCII-only reprs). Options:
/// `error_color` (colorize `Error` tokens) and `compress` (only `""` and
/// `"none"` are supported; `gz`/`bz2` need compression libraries).
pub fn raw_token_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let base = { ..base, encoding: Some("ascii"), }
  let compress = @lexer.get_choice_opt(
    options,
    "compress",
    ["", "none", "gz", "bz2"],
    "",
  )
  if compress == "gz" || compress == "bz2" {
    raise FormatterError(
      "compress=\{compress} is not supported by this port of RawTokenFormatter",
    )
  }
  let error_color = options.get("error_color")
  if error_color is Some(c) && !console_codes.contains(c) {
    raise FormatterError(
      "ValueError: Invalid color \{@pystr.repr(c)} specified",
    )
  }
  Formatter::new(raw_token_info, base, tokens => {
    let buf = StringBuilder()
    for tok in tokens {
      let line = "\{tok.0}\t\{@pystr.ascii(tok.1)}\n"
      match error_color {
        Some(c) if c != "" && tok.0 == @token.error =>
          buf.write_string(colorize(c, line))
        _ => buf.write_string(line)
      }
    }
    buf.to_string()
  })
}

///|
/// Python's `TestcaseFormatter`: a pytest test case for the token stream.
pub fn testcase_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  match base.encoding {
    None | Some("utf-8") => ()
    Some(_) =>
      raise FormatterError(
        "ValueError: Only None and utf-8 are allowed encodings.",
      )
  }
  Formatter::new(testcase_info, base, tokens => {
    let raw = StringBuilder()
    let body = StringBuilder()
    for tok in tokens {
      raw.write_string(tok.1)
      body.write_string("            (\{tok.0}, \{@pystr.repr(tok.1)}),\n")
    }
    "    def testNeedsName(lexer):\n" +
    "        fragment = \{@pystr.repr(raw.to_string())}\n" +
    "        tokens = [\n" +
    body.to_string() +
    "        ]\n" +
    "        assert list(lexer.get_tokens(fragment)) == tokens\n"
  })
}
