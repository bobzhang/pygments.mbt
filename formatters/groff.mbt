///|
/// Metadata of Python's `GroffFormatter`.
pub let groff_info : FormatterInfo = {
  class_name: "GroffFormatter",
  name: "groff",
  aliases: ["groff", "troff", "roff"],
  filenames: [],
  description: "Format tokens with groff escapes to change their color and font style.",
}

///|
/// Python's `GroffFormatter._escape_chars`.
fn groff_escape(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    match c {
      '\\' => buf.write_string("\\[u005C]")
      '.' => buf.write_string("\\[char46]")
      '\'' => buf.write_string("\\[u0027]")
      '`' => buf.write_string("\\[u0060]")
      '~' => buf.write_string("\\[u007E]")
      _ => {
        let cp = c.to_int()
        if cp < 0x80 {
          buf.write_char(c)
        } else {
          let width = if cp < 0x10000 { 4 } else { 8 }
          let hex = @pystr.upper(
            @pystr.rjust(cp.to_string(radix=16), width, fill='0'),
          )
          buf.write_string("\\[u\{hex}]")
        }
      }
    }
  }
  buf.to_string()
}

///|
/// Python's `GroffFormatter`. Options: `style`, `monospaced`, `linenos`,
/// `wrap`. As in Python, the line counter and the current line length
/// continue across `format` calls.
pub fn groff_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let monospaced = @lexer.get_bool_opt(options, "monospaced", true)
  let linenos = @lexer.get_bool_opt(options, "linenos", false)
  let wrap = @lexer.get_int_opt(options, "wrap", 0)
  let lineno = Ref(0)
  let linelen = Ref(0)
  let regular = if monospaced { "\\f[CR]" } else { "\\f[R]" }
  let bold = if monospaced { "\\f[CB]" } else { "\\f[B]" }
  let italic = if monospaced { "\\f[CI]" } else { "\\f[I]" }
  let styles : Map[@token.TokenType, (String, String)] = Map([])
  for entry in base.style.iter() {
    let (ttype, ndef) = entry
    let mut start = ""
    let mut end = ""
    if ndef.color is Some(c) {
      start += "\\m[\{c}]"
      end = "\\m[]" + end
    }
    if ndef.bold {
      start += bold
      end = regular + end
    }
    if ndef.italic {
      start += italic
      end = regular + end
    }
    if ndef.bgcolor is Some(c) {
      start += "\\M[\{c}]"
      end = "\\M[]" + end
    }
    styles[ttype] = (start, end)
  }
  let write_lineno = (buf : StringBuilder) => {
    lineno.val += 1
    buf.write_string(if lineno.val != 1 { "\n" } else { "" })
    buf.write_string(@pystr.rjust(" " + lineno.val.to_string(), 4))
    buf.write_string(" ")
  }
  // Python's `_wrap_line`
  let wrap_line = (line : String) => {
    let length = @pystr.rstrip_newlines(line).char_length()
    let space = if linenos { "     " } else { "" }
    if length > wrap {
      let buf = StringBuilder()
      for i in 0..<(length / wrap) {
        buf.write_string(@pystr.slice(line, i * wrap, end=i * wrap + wrap))
        buf.write_string("\n" + space)
      }
      let remainder = length % wrap
      if remainder > 0 {
        buf.write_string(@pystr.slice(line, length - remainder))
        linelen.val = remainder
      }
      buf.to_string()
    } else if linelen.val + length > wrap {
      linelen.val = length
      "\n" + space + line
    } else {
      linelen.val += length
      line
    }
  }
  Formatter::new(groff_info, base, tokens => {
    let buf = StringBuilder()
    // Python's `_define_colors`
    let colors = []
    for entry in base.style.iter() {
      if entry.1.color is Some(c) && !colors.contains(c) {
        colors.push(c)
      }
    }
    colors.sort_by(py_str_compare)
    for c in colors {
      buf.write_string(".defcolor \{c} rgb #\{c}\n")
    }
    buf.write_string(".nf\n\\f[CR]\n")
    if linenos {
      write_lineno(buf)
    }
    for tok in tokens {
      let t = nearest_styled(styles, tok.0)
      let (start, end) = styles.get(t).unwrap_or(("", ""))
      for line in @pystr.splitlines(tok.1, keepends=true) {
        let line = if wrap > 0 { wrap_line(line) } else { line }
        if start != "" && end != "" {
          let text = groff_escape(@pystr.rstrip_newlines(line))
          if text != "" {
            buf.write_string(start + text + end)
          }
        } else {
          buf.write_string(groff_escape(@pystr.rstrip_newlines(line)))
        }
        if line.has_suffix("\n") {
          if linenos {
            write_lineno(buf)
          } else {
            buf.write_string("\n")
          }
          linelen.val = 0
        }
      }
    }
    buf.write_string("\n.fi")
    buf.to_string()
  })
}
