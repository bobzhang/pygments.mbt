///|
/// Metadata of Python's `RtfFormatter`.
pub let rtf_info : FormatterInfo = {
  class_name: "RtfFormatter",
  name: "RTF",
  aliases: ["rtf"],
  filenames: ["*.rtf"],
  description: "Format tokens as RTF markup. This formatter automatically outputs full RTF documents with color information and other useful stuff. Perfect for Copy and Paste into Microsoft(R) Word(R) documents.",
}

///|
/// Python's `RtfFormatter._escape`.
fn rtf_escape(text : String) -> String {
  text
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="{", new="\\{")
  .replace_all(old="}", new="\\}")
}

///|
/// Python's `RtfFormatter._escape_text`: escapes RTF specials, writes
/// non-ASCII characters as `{\uN}` (surrogate pairs above U+FFFF) and
/// newlines as `\par`.
fn rtf_escape_text(text : String) -> String {
  if text == "" {
    return ""
  }
  let buf = StringBuilder()
  for c in rtf_escape(text) {
    let cn = c.to_int()
    if cn < 0x80 {
      buf.write_char(c)
    } else if cn < 0x10000 {
      buf.write_string("{\\u\{cn}}")
    } else {
      let hi = 0xd7c0 + (cn >> 10)
      let lo = 0xdc00 + (cn & 0x3ff)
      buf.write_string("{\\u\{hi}}{\\u\{lo}}")
    }
  }
  buf.to_string().replace_all(old="\n", new="\\par")
}

///|
/// Python's `RtfFormatter.hex_to_rtf_color`.
fn hex_to_rtf_color(color : String) -> String raise FormatterError {
  let c = if color.has_prefix("#") { @pystr.slice(color, 1) } else { color }
  let channel = (i : Int) => {
    let part = @pystr.slice(c, i, end=i + 2)
    match parse_hex(part) {
      Some(v) => v
      None =>
        raise FormatterError(
          "ValueError: invalid literal for int() with base 16: \{@pystr.repr(part)}",
        )
    }
  }
  "\\red\{channel(0)}\\green\{channel(2)}\\blue\{channel(4)};"
}

///|
/// Python's `_split_tokens_on_newlines`.
fn split_tokens_on_newlines(tokens : Tokens) -> Tokens {
  let out = []
  for tok in tokens {
    let (ttype, value) = tok
    if value == "\n" || !value.contains("\n") {
      out.push(tok)
    } else {
      let lines = @pystr.split(value, "\n")
      for i in 0..<(lines.length() - 1) {
        out.push((ttype, lines[i] + "\n"))
      }
      if lines[lines.length() - 1] != "" {
        out.push((ttype, lines[lines.length() - 1]))
      }
    }
  }
  out
}

///|
/// Python's `RtfFormatter`. Options: `style`, `fontface`, `fontsize`,
/// `linenos`, `lineno_fontsize`, `lineno_padding`, `linenostart`,
/// `linenostep`, `lineno_color`, `hl_lines`, `hl_color`, `hl_linenostart`.
pub fn rtf_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let st = base.style
  let fontface = options.get("fontface").unwrap_or("")
  let fontsize = @lexer.get_int_opt(options, "fontsize", 0)
  let linenos = @lexer.get_bool_opt(options, "linenos", false)
  let lineno_fontsize = @lexer.get_int_opt(options, "lineno_fontsize", fontsize)
  let lineno_padding = @lexer.get_int_opt(options, "lineno_padding", 2)
  let linenostart = abs_int_opt(options, "linenostart", 1)
  let linenostep = abs_int_opt(options, "linenostep", 1)
  let hl_linenostart = @lexer.get_bool_opt(options, "hl_linenostart", false)
  let hl_color = match options.get("hl_color") {
    Some(c) if c != "" => c
    _ => st.highlight_color.unwrap_or("None")
  }
  let hl_lines = []
  for s in @lexer.get_list_opt(options, "hl_lines", []) {
    match py_int(s) {
      Some(n) =>
        hl_lines.push(if hl_linenostart { n - linenostart + 1 } else { n })
      None => ()
    }
  }
  let lineno_color = match options.get("lineno_color") {
    Some(c) if c != "" => c
    _ =>
      if st.line_number_color == "inherit" {
        @styles.ansimap["ansibrightblack"]
      } else {
        st.line_number_color
      }
  }
  // Python's `_create_color_mapping`
  let color_mapping : Map[String, Int] = Map([])
  let mut offset = 1
  if linenos {
    color_mapping[lineno_color] = offset
    offset += 1
  }
  if hl_lines.length() > 0 {
    color_mapping[hl_color] = offset
    offset += 1
  }
  for entry in st.iter() {
    let ndef = entry.1
    for color in [ndef.color, ndef.bgcolor, ndef.border] {
      match color {
        Some(c) if !color_mapping.contains(c) => {
          color_mapping[c] = offset
          offset += 1
        }
        _ => ()
      }
    }
  }
  let padding = " ".repeat(if lineno_padding > 0 { lineno_padding } else { 0 })
  let lineno_template = (s : String) => {
    if lineno_fontsize != fontsize {
      "{\\fs\{lineno_fontsize} \\cf\{color_mapping[lineno_color]} \{s}\{padding}}"
    } else {
      "{\\cf\{color_mapping[lineno_color]} \{s}\{padding}}"
    }
  }
  Formatter::new(rtf_info, base, tokens => {
    let buf = StringBuilder()
    // Python's `_rtf_header`
    let face = if fontface != "" { " " + rtf_escape(fontface) } else { "" }
    buf.write_string(
      "{\\rtf1\\ansi\\uc0\\deff0{\\fonttbl{\\f0\\fmodern\\fprq1\\fcharset0\{face};}}\n",
    )
    buf.write_string("{\\colortbl;\n")
    for color, _ in color_mapping {
      buf.write_string(hex_to_rtf_color(color) + "\n")
    }
    buf.write_string("}\n")
    buf.write_string("\\f0\\sa0\n")
    if fontsize != 0 {
      buf.write_string("\\fs\{fontsize}\n")
    }
    buf.write_string("\\dntblnsbdb\n")
    let tokens = split_tokens_on_newlines(tokens)
    let mut linenos_width = 0
    if linenos {
      let mut line_count = 0
      for tok in tokens {
        if tok.1.has_suffix("\n") {
          line_count += 1
        }
      }
      linenos_width = (line_count + linenostart - 1).to_string().char_length()
    }
    let mut lineno = 1
    let mut start_new_line = true
    for tok in tokens {
      let (ttype, value) = tok
      if start_new_line && hl_lines.contains(lineno) {
        buf.write_string("{\\highlight\{color_mapping[hl_color]} ")
      }
      if start_new_line && linenos {
        let lineno_str = if py_mod(lineno - linenostart + 1, linenostep) == 0 {
          @pystr.rjust((lineno + linenostart - 1).to_string(), linenos_width)
        } else {
          " ".repeat(linenos_width)
        }
        buf.write_string(lineno_template(lineno_str))
      }
      let mut t = ttype
      while !st.styles_token(t) {
        match t.parent() {
          Some(p) if p != @token.token => t = p
          _ => break
        }
      }
      let style = st.style_for_token(t) catch {
        _ => raise FormatterError("KeyError: \{t}")
      }
      let start = StringBuilder()
      if style.bgcolor is Some(c) {
        start.write_string("\\cb\{color_mapping[c]}")
      }
      if style.color is Some(c) {
        start.write_string("\\cf\{color_mapping[c]}")
      }
      if style.bold {
        start.write_string("\\b")
      }
      if style.italic {
        start.write_string("\\i")
      }
      if style.underline {
        start.write_string("\\ul")
      }
      if style.border is Some(c) {
        start.write_string("\\chbrdr\\chcfpat\{color_mapping[c]}")
      }
      let start = start.to_string()
      if start != "" {
        buf.write_string("{\{start} ")
      }
      buf.write_string(rtf_escape_text(value))
      if start != "" {
        buf.write_string("}")
      }
      start_new_line = false
      if value.has_suffix("\n") {
        if hl_lines.contains(lineno) {
          buf.write_string("}")
        }
        buf.write_string("\n")
        start_new_line = true
        lineno += 1
      }
    }
    buf.write_string("}\n")
    buf.to_string()
  })
}
