///|
/// Python's `terminal.TERMINAL_COLORS`: (light background, dark background)
/// color names per token type.
pub fn terminal_colors() -> Map[@token.TokenType, (String, String)] {
  Map([
    (@token.token, ("", "")),
    (@token.whitespace, ("gray", "brightblack")),
    (@token.comment, ("gray", "brightblack")),
    (@token.comment_preproc, ("cyan", "brightcyan")),
    (@token.keyword, ("blue", "brightblue")),
    (@token.keyword_type, ("cyan", "brightcyan")),
    (@token.operator_word, ("magenta", "brightmagenta")),
    (@token.name_builtin, ("cyan", "brightcyan")),
    (@token.name_function, ("green", "brightgreen")),
    (@token.name_namespace, ("_cyan_", "_brightcyan_")),
    (@token.name_class, ("_green_", "_brightgreen_")),
    (@token.name_exception, ("cyan", "brightcyan")),
    (@token.name_decorator, ("brightblack", "gray")),
    (@token.name_variable, ("red", "brightred")),
    (@token.name_constant, ("red", "brightred")),
    (@token.name_attribute, ("cyan", "brightcyan")),
    (@token.name_tag, ("brightblue", "brightblue")),
    (@token.string, ("yellow", "yellow")),
    (@token.number, ("blue", "brightblue")),
    (@token.generic_deleted, ("brightred", "brightred")),
    (@token.generic_inserted, ("green", "brightgreen")),
    (@token.generic_heading, ("**", "**")),
    (@token.generic_subheading, ("*magenta*", "*brightmagenta*")),
    (@token.generic_prompt, ("**", "**")),
    (@token.generic_error, ("brightred", "brightred")),
    (@token.error, ("_brightred_", "_brightred_")),
  ])
}

///|
/// Metadata of Python's `TerminalFormatter`.
pub let terminal_info : FormatterInfo = {
  class_name: "TerminalFormatter",
  name: "Terminal",
  aliases: ["terminal", "console"],
  filenames: [],
  description: "Format tokens with ANSI color sequences, for output in a text console. Color sequences are terminated at newlines, so that paging the output works correctly.",
}

///|
/// The color of the nearest ancestor of `ttype` in `scheme`.
fn scheme_color(
  scheme : Map[@token.TokenType, (String, String)],
  ttype : @token.TokenType,
) -> (String, String) {
  let mut t = ttype
  while true {
    match scheme.get(t) {
      Some(c) => return c
      None =>
        match t.parent() {
          Some(p) => t = p
          None => return ("", "")
        }
    }
  }
  ("", "")
}

///|
/// Python's `TerminalFormatter` (options `bg` = `light`/`dark`, `linenos`;
/// `colorscheme` is the `colorscheme` option, which cannot be given as a
/// string). As in Python, the line counter continues across `format` calls.
pub fn terminal_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
  colorscheme? : Map[@token.TokenType, (String, String)],
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let darkbg = @lexer.get_choice_opt(options, "bg", ["light", "dark"], "light") ==
    "dark"
  let scheme = match colorscheme {
    Some(s) if s.length() > 0 => s
    _ => terminal_colors()
  }
  let linenos = truthy_opt(options, "linenos")
  let lineno = Ref(0)
  let write_lineno = (buf : StringBuilder) => {
    lineno.val += 1
    buf.write_string(if lineno.val != 1 { "\n" } else { "" })
    buf.write_string(@pystr.rjust(lineno.val.to_string(), 4, fill='0'))
    buf.write_string(": ")
  }
  Formatter::new(terminal_info, base, tokens => {
    let buf = StringBuilder()
    if linenos {
      write_lineno(buf)
    }
    for tok in tokens {
      let (ttype, value) = tok
      let colors = scheme_color(scheme, ttype)
      let color = if darkbg { colors.1 } else { colors.0 }
      for line in @pystr.splitlines(value, keepends=true) {
        let text = @pystr.rstrip_newlines(line)
        if color != "" {
          buf.write_string(ansiformat(color, text))
        } else {
          buf.write_string(text)
        }
        if line.has_suffix("\n") {
          if linenos {
            write_lineno(buf)
          } else {
            buf.write_string("\n")
          }
        }
      }
    }
    if linenos {
      buf.write_string("\n")
    }
    buf.to_string()
  })
}
