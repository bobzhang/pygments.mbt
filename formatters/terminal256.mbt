///|
/// A foreground/background color of an `EscapeSequence`: an index into the
/// xterm palette, an ANSI color name, or an RGB triple (true color).
priv enum TermColor {
  Index(Int)
  Ansi(String)
  Rgb(Int, Int, Int)
}

///|
/// Python's `terminal256.EscapeSequence`.
priv struct EscapeSequence {
  mut fg : TermColor?
  mut bg : TermColor?
  mut bold : Bool
  mut underline : Bool
  mut italic : Bool
}

///|
fn escape_attrs(attrs : Array[String]) -> String {
  if attrs.length() > 0 {
    "\u{1b}[" + attrs.join(";") + "m"
  } else {
    ""
  }
}

///|
/// The two-digit SGR code of an ANSI color name (`esc[2:4]` in Python).
fn ansi_sgr(name : String) -> String {
  let key = name.replace_all(old="ansi", new="")
  let esc = console_codes.get(key).unwrap_or("")
  if esc.length() >= 4 {
    esc.unsafe_substring(start=2, end=4)
  } else {
    ""
  }
}

///|
/// Python's `EscapeSequence.color_string`.
fn EscapeSequence::color_string(self : EscapeSequence) -> String {
  let attrs = []
  match self.fg {
    Some(Ansi(name)) => {
      let key = name.replace_all(old="ansi", new="")
      if console_codes.get(key).unwrap_or("").contains(";01m") {
        self.bold = true
      }
      attrs.push(ansi_sgr(name))
    }
    Some(Index(i)) => attrs.append(["38", "5", i.to_string()])
    Some(Rgb(_, _, _)) | None => ()
  }
  match self.bg {
    Some(Ansi(name)) => attrs.push((sgr_int(ansi_sgr(name)) + 10).to_string())
    Some(Index(i)) => attrs.append(["48", "5", i.to_string()])
    Some(Rgb(_, _, _)) | None => ()
  }
  if self.bold {
    attrs.push("01")
  }
  if self.underline {
    attrs.push("04")
  }
  if self.italic {
    attrs.push("03")
  }
  escape_attrs(attrs)
}

///|
/// `int(s)` for the SGR codes extracted from `console_codes`.
fn sgr_int(s : String) -> Int {
  py_int(s).unwrap_or(0)
}

///|
/// Python's `EscapeSequence.true_color_string`.
fn EscapeSequence::true_color_string(self : EscapeSequence) -> String {
  let attrs = []
  if self.fg is Some(Rgb(r, g, b)) {
    attrs.append(["38", "2", r.to_string(), g.to_string(), b.to_string()])
  }
  if self.bg is Some(Rgb(r, g, b)) {
    attrs.append(["48", "2", r.to_string(), g.to_string(), b.to_string()])
  }
  if self.bold {
    attrs.push("01")
  }
  if self.underline {
    attrs.push("04")
  }
  if self.italic {
    attrs.push("03")
  }
  escape_attrs(attrs)
}

///|
/// Python's `EscapeSequence.reset_string`.
fn EscapeSequence::reset_string(self : EscapeSequence) -> String {
  let attrs = []
  if self.fg is Some(_) {
    attrs.push("39")
  }
  if self.bg is Some(_) {
    attrs.push("49")
  }
  if self.bold || self.underline || self.italic {
    attrs.push("00")
  }
  escape_attrs(attrs)
}

///|
/// Python's `Terminal256Formatter._build_color_table`: the RGB values of the
/// 256 xterm colors.
let xterm_colors : Array[(Int, Int, Int)] = {
  let colors = [
    (0x00, 0x00, 0x00),
    (0xcd, 0x00, 0x00),
    (0x00, 0xcd, 0x00),
    (0xcd, 0xcd, 0x00),
    (0x00, 0x00, 0xee),
    (0xcd, 0x00, 0xcd),
    (0x00, 0xcd, 0xcd),
    (0xe5, 0xe5, 0xe5),
    (0x7f, 0x7f, 0x7f),
    (0xff, 0x00, 0x00),
    (0x00, 0xff, 0x00),
    (0xff, 0xff, 0x00),
    (0x5c, 0x5c, 0xff),
    (0xff, 0x00, 0xff),
    (0x00, 0xff, 0xff),
    (0xff, 0xff, 0xff),
  ]
  let valuerange = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]
  for i in 0..<216 {
    colors.push(
      (valuerange[i / 36 % 6], valuerange[i / 6 % 6], valuerange[i % 6]),
    )
  }
  for i in 0..<24 {
    let v = 8 + i * 10
    colors.push((v, v, v))
  }
  colors
}

///|
/// Python's `_closest_color`: the xterm color nearest to `(r, g, b)`.
fn closest_color(r : Int, g : Int, b : Int) -> Int {
  let mut distance = 257 * 257 * 3
  let mut best = 0
  for i in 0..<256 {
    let (vr, vg, vb) = xterm_colors[i]
    let rd = r - vr
    let gd = g - vg
    let bd = b - vb
    let d = rd * rd + gd * gd + bd * bd
    if d < distance {
      best = i
      distance = d
    }
  }
  best
}

///|
/// Python's `_color_index`.
fn color_index(color : String) -> TermColor {
  if @styles.is_ansicolor(color) {
    return Ansi(color)
  }
  let rgb = parse_hex(color).unwrap_or(0)
  Index(closest_color((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff))
}

///|
/// Python's `TerminalTrueColorFormatter._color_tuple`.
fn color_tuple(color : String) -> TermColor? {
  match parse_hex(color) {
    Some(rgb) => Some(Rgb((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff))
    None => None
  }
}

///|
/// Metadata of Python's `Terminal256Formatter`.
pub let terminal256_info : FormatterInfo = {
  class_name: "Terminal256Formatter",
  name: "Terminal256",
  aliases: ["terminal256", "console256", "256"],
  filenames: [],
  description: "Format tokens with ANSI color sequences, for output in a 256-color terminal or console.  Like in `TerminalFormatter` color sequences are terminated at newlines, so that paging the output works correctly.",
}

///|
/// Metadata of Python's `TerminalTrueColorFormatter`.
pub let terminal_true_color_info : FormatterInfo = {
  class_name: "TerminalTrueColorFormatter",
  name: "TerminalTrueColor",
  aliases: ["terminal16m", "console16m", "16m"],
  filenames: [],
  description: "Format tokens with ANSI color sequences, for output in a true-color terminal or console.  Like in `TerminalFormatter` color sequences are terminated at newlines, so that paging the output works correctly.",
}

///|
/// Shared implementation of the 256-color and true-color formatters.
fn terminal256_impl(
  info : FormatterInfo,
  options : @lexer.Options,
  style : @styles.Style?,
  true_color : Bool,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let usebold = !options.contains("nobold")
  let useunderline = !options.contains("nounderline")
  let useitalic = !options.contains("noitalic")
  let style_string : Map[@token.TokenType, (String, String)] = Map([])
  for entry in base.style.iter() {
    let (ttype, ndef) = entry
    let esc : EscapeSequence = {
      fg: None,
      bg: None,
      bold: false,
      underline: false,
      italic: false,
    }
    if true_color {
      if ndef.color is Some(c) {
        esc.fg = color_tuple(c)
      }
      if ndef.bgcolor is Some(c) {
        esc.bg = color_tuple(c)
      }
    } else {
      match (ndef.ansicolor, ndef.color) {
        (Some(c), _) | (None, Some(c)) => esc.fg = Some(color_index(c))
        _ => ()
      }
      match (ndef.bgansicolor, ndef.bgcolor) {
        (Some(c), _) | (None, Some(c)) => esc.bg = Some(color_index(c))
        _ => ()
      }
    }
    if usebold && ndef.bold {
      esc.bold = true
    }
    if useunderline && ndef.underline {
      esc.underline = true
    }
    if useitalic && ndef.italic {
      esc.italic = true
    }
    let on = if true_color {
      esc.true_color_string()
    } else {
      esc.color_string()
    }
    style_string[ttype] = (on, esc.reset_string())
  }
  let linenos = truthy_opt(options, "linenos")
  let lineno = Ref(0)
  let write_lineno = (buf : StringBuilder) => {
    lineno.val += 1
    buf.write_string(if lineno.val != 1 { "\n" } else { "" })
    buf.write_string(@pystr.rjust(lineno.val.to_string(), 4, fill='0'))
    buf.write_string(": ")
  }
  Formatter::new(info, base, tokens => {
    let buf = StringBuilder()
    if linenos {
      write_lineno(buf)
    }
    for tok in tokens {
      let (ttype, value) = tok
      // Python stops at the root: `Token` is an empty (false) tuple
      let mut t = ttype
      let mut found = None
      while t != @token.token {
        match style_string.get(t) {
          Some(s) => {
            found = Some(s)
            break
          }
          None => t = t.parent().unwrap_or(@token.token)
        }
      }
      match found {
        // fast path: most tokens contain no newline
        Some((on, off)) if !value.contains("\n") =>
          if value != "" {
            buf.write_string(on)
            buf.write_string(value)
            buf.write_string(off)
          }
        Some((on, off)) => {
          let spl = @pystr.split(value, "\n")
          for i in 0..<(spl.length() - 1) {
            let line = spl[i]
            if line != "" {
              buf.write_string(on)
              buf.write_string(line)
              buf.write_string(off)
            }
            if linenos {
              write_lineno(buf)
            } else {
              buf.write_string("\n")
            }
          }
          let last = spl[spl.length() - 1]
          if last != "" {
            buf.write_string(on)
            buf.write_string(last)
            buf.write_string(off)
          }
        }
        None => buf.write_string(value)
      }
    }
    if linenos {
      buf.write_string("\n")
    }
    buf.to_string()
  })
}

///|
/// Python's `Terminal256Formatter` (options `style`, `linenos`, and the
/// presence of `nobold`/`nounderline`/`noitalic`).
pub fn terminal256_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  terminal256_impl(terminal256_info, options, style, false)
}

///|
/// Python's `TerminalTrueColorFormatter`.
pub fn terminal_true_color_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  terminal256_impl(terminal_true_color_info, options, style, true)
}
