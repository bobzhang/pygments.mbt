///|
/// Metadata of Python's `BBCodeFormatter`.
pub let bbcode_info : FormatterInfo = {
  class_name: "BBCodeFormatter",
  name: "BBCode",
  aliases: ["bbcode", "bb"],
  filenames: [],
  description: "Format tokens with BBcodes. These formatting codes are used by many bulletin boards, so you can highlight your sourcecode with pygments before posting it there.",
}

///|
/// Metadata of Python's `PangoMarkupFormatter`.
pub let pango_info : FormatterInfo = {
  class_name: "PangoMarkupFormatter",
  name: "Pango Markup",
  aliases: ["pango", "pangomarkup"],
  filenames: [],
  description: "Format tokens as Pango Markup code. It can then be rendered to an SVG.",
}

///|
/// The nearest ancestor of `ttype` present in `styles`.
fn nearest_styled(
  styles : Map[@token.TokenType, (String, String)],
  ttype : @token.TokenType,
) -> @token.TokenType {
  let mut t = ttype
  while !styles.contains(t) {
    match t.parent() {
      Some(p) => t = p
      None => break
    }
  }
  t
}

///|
/// Merges runs of tokens with the same (resolved) style and wraps each run
/// in its start/end markup (the loop shared by the BBCode and Pango
/// formatters).
fn write_merged(
  buf : StringBuilder,
  styles : Map[@token.TokenType, (String, String)],
  tokens : Tokens,
  escape : (String) -> String,
) -> Unit {
  let lastval = StringBuilder()
  let mut lasttype : @token.TokenType? = None
  let flush = (t : @token.TokenType?) => {
    if lastval.to_string() != "" {
      let (start, end) = match t {
        Some(t) => styles.get(t).unwrap_or(("", ""))
        None => ("", "")
      }
      buf.write_string(start)
      buf.write_string(lastval.to_string())
      buf.write_string(end)
    }
  }
  for tok in tokens {
    let ttype = nearest_styled(styles, tok.0)
    if lasttype == Some(ttype) {
      lastval.write_string(escape(tok.1))
    } else {
      flush(lasttype)
      lastval.reset()
      lastval.write_string(escape(tok.1))
      lasttype = Some(ttype)
    }
  }
  flush(lasttype)
}

///|
/// Python's `BBCodeFormatter`. Options: `style`, `codetag`, `monofont`.
pub fn bbcode_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let code = @lexer.get_bool_opt(options, "codetag", false)
  let mono = @lexer.get_bool_opt(options, "monofont", false)
  let styles : Map[@token.TokenType, (String, String)] = Map([])
  for entry in base.style.iter() {
    let (ttype, ndef) = entry
    let mut start = ""
    let mut end = ""
    if ndef.color is Some(c) {
      start += "[color=#\{c}]"
      end = "[/color]" + end
    }
    if ndef.bold {
      start += "[b]"
      end = "[/b]" + end
    }
    if ndef.italic {
      start += "[i]"
      end = "[/i]" + end
    }
    if ndef.underline {
      start += "[u]"
      end = "[/u]" + end
    }
    styles[ttype] = (start, end)
  }
  Formatter::new(bbcode_info, base, tokens => {
    let buf = StringBuilder()
    if code {
      buf.write_string("[code]")
    }
    if mono {
      buf.write_string("[font=monospace]")
    }
    write_merged(buf, styles, tokens, s => s)
    if mono {
      buf.write_string("[/font]")
    }
    if code {
      buf.write_string("[/code]")
    }
    if code || mono {
      buf.write_string("\n")
    }
    buf.to_string()
  })
}

///|
/// Python's `pangomarkup.escape_special_chars`.
fn pango_escape(text : String) -> String {
  text.replace_all(old="&", new="&amp;").replace_all(old="<", new="&lt;")
}

///|
/// Python's `PangoMarkupFormatter`. Options: `style`.
pub fn pango_markup_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let styles : Map[@token.TokenType, (String, String)] = Map([])
  for entry in base.style.iter() {
    let (ttype, ndef) = entry
    let mut start = ""
    let mut end = ""
    if ndef.color is Some(c) {
      start += "<span fgcolor=\"#\{c}\">"
      end = "</span>" + end
    }
    if ndef.bold {
      start += "<b>"
      end = "</b>" + end
    }
    if ndef.italic {
      start += "<i>"
      end = "</i>" + end
    }
    if ndef.underline {
      start += "<u>"
      end = "</u>" + end
    }
    styles[ttype] = (start, end)
  }
  Formatter::new(pango_info, base, tokens => {
    let buf = StringBuilder()
    buf.write_string("<tt>")
    write_merged(buf, styles, tokens, pango_escape)
    buf.write_string("</tt>")
    buf.to_string()
  })
}
