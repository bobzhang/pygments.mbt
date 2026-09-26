///|
/// Python's `irc.IRC_COLORS`: (light background, dark background) color
/// names per token type.
pub fn irc_colors() -> Map[@token.TokenType, (String, String)] {
  Map([
    (@token.token, ("", "")),
    (@token.whitespace, ("gray", "brightblack")),
    (@token.comment, ("gray", "brightblack")),
    (@token.comment_preproc, ("cyan", "brightcyan")),
    (@token.keyword, ("blue", "brightblue")),
    (@token.keyword_type, ("cyan", "brightcyan")),
    (@token.operator_word, ("magenta", "brightcyan")),
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
    (@token.generic_error, ("brightred", "brightred")),
    (@token.error, ("_brightred_", "_brightred_")),
  ])
}

///|
/// Python's `irc.IRC_COLOR_MAP`: mIRC color numbers.
let irc_color_map : Map[String, Int] = {
  "white": 0,
  "black": 1,
  "blue": 2,
  "brightgreen": 3,
  "brightred": 4,
  "yellow": 5,
  "magenta": 6,
  "orange": 7,
  "green": 7,
  "brightyellow": 8,
  "lightgreen": 9,
  "brightcyan": 9,
  "cyan": 10,
  "lightblue": 11,
  "red": 11,
  "brightblue": 12,
  "brightmagenta": 13,
  "brightblack": 14,
  "gray": 15,
}

///|
/// Python's `str.strip(ch)` for one character.
fn strip_char(s : String, ch : String) -> String {
  s.trim(chars=ch).to_owned()
}

///|
/// Python's `irc.ircformat`: `text` wrapped in IRC color/attribute codes.
pub fn ircformat(color : String, text : String) -> String raise FormatterError {
  if color == "" {
    return text
  }
  let mut color = color
  let mut add = ""
  let mut sub = ""
  if color.contains("_") {
    add += "\u{1d}"
    sub = "\u{1d}" + sub
    color = strip_char(color, "_")
  }
  if color.contains("*") {
    add += "\u{02}"
    sub = "\u{02}" + sub
    color = strip_char(color, "*")
  }
  if color != "" {
    match irc_color_map.get(color) {
      Some(n) => {
        add += "\u{03}" + @pystr.rjust(n.to_string(), 2, fill='0')
        sub = "\u{03}" + sub
      }
      None => raise FormatterError("KeyError: \{@pystr.repr(color)}")
    }
  }
  add + text + sub
}

///|
/// Metadata of Python's `IRCFormatter`.
pub let irc_info : FormatterInfo = {
  class_name: "IRCFormatter",
  name: "IRC",
  aliases: ["irc", "IRC"],
  filenames: [],
  description: "Format tokens with IRC color sequences",
}

///|
/// Python's `IRCFormatter` (options `bg`, `linenos`; `colorscheme` as a
/// map). As in Python, the line counter continues across `format` calls.
pub fn irc_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
  colorscheme? : Map[@token.TokenType, (String, String)],
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let darkbg = @lexer.get_choice_opt(options, "bg", ["light", "dark"], "light") ==
    "dark"
  let scheme = match colorscheme {
    Some(s) if s.length() > 0 => s
    _ => irc_colors()
  }
  let linenos = truthy_opt(options, "linenos")
  let lineno = Ref(0)
  let write_lineno = (buf : StringBuilder) => {
    if linenos {
      lineno.val += 1
      buf.write_string(@pystr.rjust(lineno.val.to_string(), 4, fill='0'))
      buf.write_string(": ")
    }
  }
  Formatter::new(irc_info, base, tokens => {
    let buf = StringBuilder()
    write_lineno(buf)
    for tok in tokens {
      let (ttype, value) = tok
      let colors = scheme_color(scheme, ttype)
      let color = if darkbg { colors.1 } else { colors.0 }
      let spl = @pystr.split(value, "\n")
      for i in 0..<(spl.length() - 1) {
        if spl[i] != "" {
          buf.write_string(ircformat(color, spl[i]))
        }
        buf.write_string("\n")
        write_lineno(buf)
      }
      let last = spl[spl.length() - 1]
      if last != "" {
        buf.write_string(ircformat(color, last))
      }
    }
    buf.to_string()
  })
}
