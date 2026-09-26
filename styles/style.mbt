///|
/// Errors raised while building or querying a style.
pub suberror StyleError {
  /// A color that `StyleMeta.colorformat` rejects.
  WrongColorFormat(String)
  /// `style_for_token` on a token type the style does not know (Python's
  /// `KeyError`).
  UnknownToken(@token.TokenType)
} derive(Debug)

///|
/// The processed definition of one token type (Python's `_styles` list
/// `[color, bold, italic, underline, bgcolor, border, roman, sans, mono]`).
/// Colors are normalised: `""`, a 6-digit hex value without `#`, an ANSI
/// color name, `transparent`, or a CSS `var(...)`/`calc(...)` expression.
pub(all) struct StyleDef {
  color : String
  bold : Bool
  italic : Bool
  underline : Bool
  bgcolor : String
  border : String
  roman : Bool
  sans : Bool
  mono : Bool
} derive(Eq, Debug)

///|
/// Python's `style_for_token` dictionary. `None` stands for Python's `None`;
/// `roman`, `sans` and `mono` are `True` or `None` in Python, `true` or
/// `false` here.
pub(all) struct TokenStyle {
  color : String?
  bold : Bool
  italic : Bool
  underline : Bool
  bgcolor : String?
  border : String?
  roman : Bool
  sans : Bool
  mono : Bool
  ansicolor : String?
  bgansicolor : String?
} derive(Eq, Debug)

///|
/// A highlighting style: the equivalent of a `pygments.style.Style` class
/// after `StyleMeta` processed it.
pub struct Style {
  /// User-friendly style name (`default`, `monokai`, ...).
  name : String
  aliases : Array[String]
  /// Overall background color; `None` means transparent.
  background_color : String?
  /// Background color of highlighted lines.
  highlight_color : String?
  line_number_color : String
  line_number_background_color : String
  line_number_special_color : String
  line_number_special_background_color : String
  /// Hidden from the style gallery (language-specific styles).
  web_style_gallery_exclude : Bool
  /// The raw style strings, one per token type (Python's `styles`, after the
  /// metaclass added an empty entry for every standard token type).
  styles : Map[@token.TokenType, String]
  priv defs : Map[@token.TokenType, StyleDef]
}

///|
let empty_def : StyleDef = {
  color: "",
  bold: false,
  italic: false,
  underline: false,
  bgcolor: "",
  border: "",
  roman: false,
  sans: false,
  mono: false,
}

///|
/// Python's `StyleMeta.colorformat`.
pub fn colorformat(text : String) -> String raise StyleError {
  if is_ansicolor(text) {
    return text
  }
  if text.has_prefix("#") {
    let col = text.unsafe_substring(start=1, end=text.length())
    if col.length() == 6 {
      return col
    }
    if col.length() == 3 {
      let buf = StringBuilder()
      for c in col {
        buf.write_char(c)
        buf.write_char(c)
      }
      return buf.to_string()
    }
  } else if text == "" || text == "transparent" {
    return text
  } else if text.has_prefix("var") || text.has_prefix("calc") {
    return text
  }
  raise WrongColorFormat(text)
}

///|
/// Applies the words of a style string to `ndef` (the body of the
/// `StyleMeta` loop).
fn apply_styledefs(
  ndef : StyleDef,
  words : Array[String],
) -> StyleDef raise StyleError {
  let mut d = ndef
  for w in words {
    match w {
      "noinherit" => ()
      "bold" => d = { ..d, bold: true, }
      "nobold" => d = { ..d, bold: false, }
      "italic" => d = { ..d, italic: true, }
      "noitalic" => d = { ..d, italic: false, }
      "underline" => d = { ..d, underline: true, }
      "nounderline" => d = { ..d, underline: false, }
      "roman" => d = { ..d, roman: true, }
      "sans" => d = { ..d, sans: true, }
      "mono" => d = { ..d, mono: true, }
      _ =>
        if w.has_prefix("bg:") {
          d = {
            ..d,
            bgcolor: colorformat(w.unsafe_substring(start=3, end=w.length())),
          }
        } else if w.has_prefix("border:") {
          d = {
            ..d,
            border: colorformat(w.unsafe_substring(start=7, end=w.length())),
          }
        } else {
          d = { ..d, color: colorformat(w), }
        }
    }
  }
  d
}

///|
/// Python's `str.split()` (whitespace separated words) for style strings.
fn words(s : String) -> Array[String] {
  let out = []
  let buf = StringBuilder()
  for c in s {
    match c {
      ' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' =>
        if buf.to_string() != "" {
          out.push(buf.to_string())
          buf.reset()
        }
      _ => buf.write_char(c)
    }
  }
  if buf.to_string() != "" {
    out.push(buf.to_string())
  }
  out
}

///|
/// Builds a style from its `styles` entries (token type, style string), like
/// defining a `Style` subclass in Python. Entries for standard token types
/// that are missing are added (empty), as `StyleMeta` does.
///
/// ```mbt check
/// test {
///   let st = @styles.Style::new([
///     (@token.keyword, "bold #008000"),
///     (@token.keyword_type, "nobold"),
///   ])
///   let kt = st.style_for_token(@token.keyword_type)
///   inspect(kt.color.unwrap_or("-"), content="008000")
///   inspect(kt.bold, content="false")
/// }
/// ```
pub fn Style::new(
  styles : Array[(@token.TokenType, String)],
  name? : String = "unnamed",
  aliases? : Array[String] = [],
  background_color? : String? = Some("#ffffff"),
  highlight_color? : String? = Some("#ffffcc"),
  line_number_color? : String = "inherit",
  line_number_background_color? : String = "transparent",
  line_number_special_color? : String = "#000000",
  line_number_special_background_color? : String = "#ffffc0",
  web_style_gallery_exclude? : Bool = false,
) -> Style raise StyleError {
  let raw : Map[@token.TokenType, String] = Map::from_array(styles)
  for t, _ in @token.standard_names() {
    if !raw.contains(t) {
      raw[t] = ""
    }
  }
  let defs : Map[@token.TokenType, StyleDef] = Map([])
  for ttype, _ in raw {
    for tok in ttype.split() {
      if defs.contains(tok) {
        continue
      }
      let styledefs = words(raw.get(tok).unwrap_or(""))
      let parent = match tok.parent() {
        Some(p) => defs.get(p)
        None => None
      }
      let ndef = match parent {
        None => empty_def
        Some(_) if styledefs.contains("noinherit") && tok != @token.token =>
          defs[@token.token]
        Some(p) => p
      }
      defs[tok] = apply_styledefs(ndef, styledefs)
    }
  }
  {
    name,
    aliases,
    background_color,
    highlight_color,
    line_number_color,
    line_number_background_color,
    line_number_special_color,
    line_number_special_background_color,
    web_style_gallery_exclude,
    styles: raw,
    defs,
  }
}

///|
/// The processed definition of `ttype` (Python's `cls._styles[ttype]`).
pub fn Style::style_def(self : Style, ttype : @token.TokenType) -> StyleDef? {
  self.defs.get(ttype)
}

///|
/// Python's `style_for_token`: the style of `ttype` with ANSI color names
/// resolved to RGB values.
pub fn Style::style_for_token(
  self : Style,
  ttype : @token.TokenType,
) -> TokenStyle raise StyleError {
  match self.defs.get(ttype) {
    Some(d) => token_style(d)
    None => raise UnknownToken(ttype)
  }
}

///|
fn resolve_ansi(color : String) -> (String, String?) {
  let color = deprecated_ansicolors.get(color).unwrap_or(color)
  match ansimap.get(color) {
    Some(rgb) => (rgb, Some(color))
    None => (color, None)
  }
}

///|
fn non_empty(s : String) -> String? {
  if s == "" {
    None
  } else {
    Some(s)
  }
}

///|
fn token_style(t : StyleDef) -> TokenStyle {
  let (color, ansicolor) = resolve_ansi(t.color)
  let (bgcolor, bgansicolor) = resolve_ansi(t.bgcolor)
  {
    color: non_empty(color),
    bold: t.bold,
    italic: t.italic,
    underline: t.underline,
    bgcolor: non_empty(bgcolor),
    border: non_empty(t.border),
    roman: t.roman,
    sans: t.sans,
    mono: t.mono,
    ansicolor,
    bgansicolor,
  }
}

///|
/// Python's `styles_token`: whether the style defines `ttype`.
pub fn Style::styles_token(self : Style, ttype : @token.TokenType) -> Bool {
  self.defs.contains(ttype)
}

///|
/// Python's `__iter__`: every token type the style knows, in definition
/// order, with its `style_for_token` dictionary.
pub fn Style::iter(self : Style) -> Iter[(@token.TokenType, TokenStyle)] {
  self.defs.iter().map(p => (p.0, token_style(p.1)))
}

///|
/// Python's `list_styles`.
pub fn Style::list_styles(
  self : Style,
) -> Array[(@token.TokenType, TokenStyle)] {
  self.iter().collect()
}

///|
/// Python's `__len__`: the number of token types the style knows.
pub fn Style::length(self : Style) -> Int {
  self.defs.length()
}
