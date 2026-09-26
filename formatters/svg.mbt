///|
/// Metadata of Python's `SvgFormatter`.
pub let svg_info : FormatterInfo = {
  class_name: "SvgFormatter",
  name: "SVG",
  aliases: ["svg"],
  filenames: ["*.svg"],
  description: "Format tokens as an SVG graphics file.  This formatter is still experimental. Each line of code is a ``<text>`` element with explicit ``x`` and ``y`` coordinates containing ``<tspan>`` elements with the individual token styles.",
}

///|
/// Python's `SvgFormatter`. Options: `style`, `nowrap`, `fontfamily`,
/// `fontsize`, `xoffset`, `yoffset`, `ystep`, `spacehack`, `linenos`,
/// `linenostart`, `linenostep`, `linenowidth`.
pub fn svg_formatter(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = BaseOptions::new(options, style?)
  let st = base.style
  let nowrap = @lexer.get_bool_opt(options, "nowrap", false)
  let fontfamily = options.get("fontfamily").unwrap_or("monospace")
  let fontsize = options.get("fontsize").unwrap_or("14px")
  let xoffset = @lexer.get_int_opt(options, "xoffset", 0)
  let mut fs = fontsize.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
  if fs.has_suffix("px") {
    fs = fs
      .unsafe_substring(start=0, end=fs.length() - 2)
      .trim(chars=" \t\n\r\u{0b}\u{0c}")
      .to_owned()
  }
  let int_fs = py_int(fs).unwrap_or(20)
  let yoffset = @lexer.get_int_opt(options, "yoffset", int_fs)
  let ystep = @lexer.get_int_opt(options, "ystep", int_fs + 5)
  let spacehack = @lexer.get_bool_opt(options, "spacehack", true)
  let linenos = @lexer.get_bool_opt(options, "linenos", false)
  let linenostart = @lexer.get_int_opt(options, "linenostart", 1)
  let linenostep = @lexer.get_int_opt(options, "linenostep", 1)
  let linenowidth = @lexer.get_int_opt(options, "linenowidth", 3 * ystep)
  let stylecache : Map[@token.TokenType, String] = Map([])
  // Python's `_get_style`
  fn get_style(tokentype : @token.TokenType) -> String {
    if stylecache.get(tokentype) is Some(s) {
      return s
    }
    let mut t = tokentype
    while !st.styles_token(t) {
      t = t.parent().unwrap_or(@token.token)
    }
    let value = st.style_for_token(t) catch { _ => panic() }
    let result = StringBuilder()
    if value.color is Some(c) {
      result.write_string(" fill=\"#" + c + "\"")
    }
    if value.bold {
      result.write_string(" font-weight=\"bold\"")
    }
    if value.italic {
      result.write_string(" font-style=\"italic\"")
    }
    let result = result.to_string()
    stylecache[tokentype] = result
    result
  }
  Formatter::new(svg_info, base, tokens => {
    let buf = StringBuilder()
    let x = xoffset
    let mut y = yoffset
    if !nowrap {
      match base.encoding {
        Some(enc) =>
          buf.write_string("<?xml version=\"1.0\" encoding=\"\{enc}\"?>\n")
        None => buf.write_string("<?xml version=\"1.0\"?>\n")
      }
      buf.write_string(
        "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.0//EN\" \"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd\">\n",
      )
      buf.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\">\n")
      buf.write_string(
        "<g font-family=\"\{fontfamily}\" font-size=\"\{fontsize}\">\n",
      )
    }
    let mut counter = linenostart
    let counter_step = linenostep
    let counter_style = get_style(@token.comment)
    let mut line_x = x
    if linenos {
      if py_mod(counter, counter_step) == 0 {
        buf.write_string(
          "<text x=\"\{x + linenowidth}\" y=\"\{y}\" \{counter_style} text-anchor=\"end\">\{counter}</text>",
        )
      }
      line_x += linenowidth + ystep
      counter += 1
    }
    buf.write_string("<text x=\"\{line_x}\" y=\"\{y}\" xml:space=\"preserve\">")
    for tok in tokens {
      let (ttype, value) = tok
      let style = get_style(ttype)
      let tspan = if style != "" { "<tspan" + style + ">" } else { "" }
      let tspanend = if tspan != "" { "</tspan>" } else { "" }
      let mut value = @pystr.html_escape(value)
      if spacehack {
        value = @pystr.expandtabs(value).replace_all(old=" ", new="&#160;")
      }
      let parts = @pystr.split(value, "\n")
      for i in 0..<(parts.length() - 1) {
        buf.write_string(tspan + parts[i] + tspanend)
        y += ystep
        buf.write_string("</text>\n")
        if linenos && py_mod(counter, counter_step) == 0 {
          buf.write_string(
            "<text x=\"\{x + linenowidth}\" y=\"\{y}\" text-anchor=\"end\" \{counter_style}>\{counter}</text>",
          )
        }
        counter += 1
        buf.write_string(
          "<text x=\"\{line_x}\" y=\"\{y}\" xml:space=\"preserve\">",
        )
      }
      buf.write_string(tspan + parts[parts.length() - 1] + tspanend)
    }
    buf.write_string("</text>")
    if !nowrap {
      buf.write_string("</g></svg>\n")
    }
    buf.to_string()
  })
}
