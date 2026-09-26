///|
/// A piece of HTML output: `(1, line)` for a line of highlighted source,
/// `(0, text)` for wrapping markup (Python's generator protocol).
type Piece = (Int, String)

///|
/// Python's `_format_lines`: the highlighted lines, without wrapping.
fn HtmlFormatter::format_lines(
  self : HtmlFormatter,
  tokens : Tokens,
) -> Array[Piece] {
  let out : Array[Piece] = []
  let nocls = self.noclasses
  let lsep = self.lineseparator
  let mut lspan = ""
  let line : Array[String] = []
  for tok in tokens {
    let (ttype, value) = tok
    let cspan = match self.span_openers.get(ttype) {
      Some(s) => s
      None => {
        let title = if self.debug_token_types {
          " title=\"\{ttype_repr_tail(ttype)}\""
        } else {
          ""
        }
        let s = if nocls {
          let css = self.get_css_inline_styles(ttype)
          if css != "" {
            let st = self.class2style.get(css).map(v => v.0).unwrap_or("")
            "<span style=\"\{st}\"\{title}>"
          } else {
            ""
          }
        } else {
          let css = self.get_css_classes(ttype)
          if css != "" {
            "<span class=\"\{css}\"\{title}>"
          } else {
            ""
          }
        }
        self.span_openers[ttype] = s
        s
      }
    }
    let close_c = if cspan != "" { "</span>" } else { "" }
    let parts = @pystr.split(@pystr.html_escape(value, quote=false), "\n")
    for i in 0..<(parts.length() - 1) {
      let part = parts[i]
      if line.length() > 0 {
        let close_l = if lspan != "" { "</span>" } else { "" }
        if lspan != cspan && part != "" {
          line.push(close_l)
          line.push(cspan)
          line.push(part)
          line.push(close_c)
          line.push(lsep)
        } else {
          line.push(part)
          line.push(close_l)
          line.push(lsep)
        }
        out.push((1, line.join("")))
        line.clear()
      } else if part != "" {
        out.push((1, cspan + part + close_c + lsep))
      } else {
        out.push((1, lsep))
      }
    }
    let last = parts[parts.length() - 1]
    if line.length() > 0 && last != "" {
      if lspan != cspan {
        line.push(if lspan != "" { "</span>" } else { "" })
        line.push(cspan)
        line.push(last)
        lspan = cspan
      } else {
        line.push(last)
      }
    } else if last != "" {
      line.clear()
      line.push(cspan)
      line.push(last)
      lspan = cspan
    }
  }
  if line.length() > 0 {
    line.push(if lspan != "" { "</span>" } else { "" })
    line.push(lsep)
    out.push((1, line.join("")))
  }
  out
}

///|
/// Python's `'%*d' % (width, n)`.
fn pad_num(n : Int, width : Int) -> String {
  @pystr.rjust(n.to_string(), width)
}

///|
/// Python's `_wrap_tablelinenos`.
fn HtmlFormatter::wrap_tablelinenos(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] raise FormatterError {
  let dummy = StringBuilder()
  let mut lncount = 0
  for p in inner {
    if p.0 != 0 {
      lncount += 1
    }
    dummy.write_string(p.1)
  }
  let fl = self.linenostart
  let mw = (lncount + fl - 1).to_string().length()
  let sp = self.linenospecial
  let st = self.linenostep
  let anchor_name = if self.lineanchors != "" {
    self.lineanchors
  } else {
    self.linespans
  }
  let lines = []
  for i = fl; i < fl + lncount; i = i + 1 {
    let print_line = py_mod(i, st) == 0
    let special_line = sp != 0 && py_mod(i, sp) == 0
    let mut line = if print_line {
      let l = pad_num(i, mw)
      if self.anchorlinenos {
        "<a href=\"#\{anchor_name}-\{i}\">\{l}</a>"
      } else {
        l
      }
    } else {
      " ".repeat(mw)
    }
    let style = if self.noclasses {
      if special_line {
        " style=\"\{self.linenos_special_style()}\""
      } else {
        " style=\"\{self.linenos_style()}\""
      }
    } else if special_line {
      " class=\"special\""
    } else {
      " class=\"normal\""
    }
    line = "<span\{style}>\{line}</span>"
    lines.push(line)
  }
  let ls = lines.join("\n")
  let filename_tr = if self.filename != "" {
    "<tr><th colspan=\"2\" class=\"filename\"><span class=\"filename\">" +
    self.filename +
    "</span></th></tr>"
  } else {
    ""
  }
  [
    (
      0,
      "<table class=\"\{self.cssclass}table\">" +
      filename_tr +
      "<tr><td class=\"linenos\"><div class=\"linenodiv\"><pre>" +
      ls +
      "</pre></div></td><td class=\"code\">",
    ),
    (0, "<div>"),
    (0, dummy.to_string()),
    (0, "</div>"),
    (0, "</td></tr></table>"),
  ]
}

///|
/// Python's `_wrap_inlinelinenos`.
fn HtmlFormatter::wrap_inlinelinenos(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] raise FormatterError {
  let sp = self.linenospecial
  let st = self.linenostep
  let mut num = self.linenostart
  let mw = (inner.length() + num - 1).to_string().length()
  let anchor_name = if self.lineanchors != "" {
    self.lineanchors
  } else {
    self.linespans
  }
  let out = []
  for p in inner {
    let print_line = py_mod(num, st) == 0
    let special_line = sp != 0 && py_mod(num, sp) == 0
    let line = if print_line { pad_num(num, mw) } else { " ".repeat(mw) }
    let style = if self.noclasses {
      if special_line {
        " style=\"\{self.linenos_special_style()}\""
      } else {
        " style=\"\{self.linenos_style()}\""
      }
    } else if special_line {
      " class=\"linenos special\""
    } else {
      " class=\"linenos\""
    }
    let linenos = "<span\{style}>\{line}</span>"
    if self.anchorlinenos {
      out.push((1, "<a href=\"#\{anchor_name}-\{num}\">\{linenos}</a>" + p.1))
    } else {
      out.push((1, linenos + p.1))
    }
    num += 1
  }
  out
}

///|
/// Python's `_wrap_lineanchors`.
fn HtmlFormatter::wrap_lineanchors(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let s = self.lineanchors
  let mut i = self.linenostart - 1
  inner.map(p => {
    if p.0 != 0 {
      i += 1
      let href = if self.linenos != 0 { "" } else { " href=\"#\{s}-\{i}\"" }
      (1, "<a id=\"\{s}-\{i}\" name=\"\{s}-\{i}\"\{href}></a>" + p.1)
    } else {
      (0, p.1)
    }
  })
}

///|
/// Python's `_wrap_linespans`.
fn HtmlFormatter::wrap_linespans(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let s = self.linespans
  let mut i = self.linenostart - 1
  inner.map(p => {
    if p.0 != 0 {
      i += 1
      (1, "<span id=\"\{s}-\{i}\">\{p.1}</span>")
    } else {
      (0, p.1)
    }
  })
}

///|
/// Python's `_wrap_div`.
fn HtmlFormatter::wrap_div(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let style = []
  if self.noclasses && !self.nobackground {
    match self.base.style.background_color {
      Some(bg) => style.push("background: \{bg}")
      None => ()
    }
  }
  if self.cssstyles != "" {
    style.push(self.cssstyles)
  }
  let style = style.join("; ")
  let cls = if self.cssclass != "" { " class=\"\{self.cssclass}\"" } else { "" }
  let st = if style != "" { " style=\"\{style}\"" } else { "" }
  let out = [(0, "<div" + cls + st + ">")]
  out.append(inner)
  out.push((0, "</div>\n"))
  out
}

///|
/// Python's `_wrap_pre`.
fn HtmlFormatter::wrap_pre(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let style = []
  if self.prestyles != "" {
    style.push(self.prestyles)
  }
  if self.noclasses {
    style.push(pre_style)
  }
  let style = style.join("; ")
  let out = []
  if self.filename != "" && self.linenos != 1 {
    out.push((0, "<span class=\"filename\">" + self.filename + "</span>"))
  }
  let st = if style != "" { " style=\"\{style}\"" } else { "" }
  out.push((0, "<pre" + st + "><span></span>"))
  out.append(inner)
  out.push((0, "</pre>"))
  out
}

///|
/// Python's `_wrap_code`.
fn wrap_code(inner : Array[Piece]) -> Array[Piece] {
  let out = [(0, "<code>")]
  out.append(inner)
  out.push((0, "</code>"))
  out
}

///|
/// Python's `_highlight_lines`.
fn HtmlFormatter::highlight_lines(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let out = []
  for i, p in inner {
    let (t, value) = p
    if t != 1 {
      out.push((t, value))
    }
    if self.hl_lines.contains(i + 1) {
      if self.noclasses {
        let style = match self.base.style.highlight_color {
          Some(c) => " style=\"background-color: \{c}\""
          None => ""
        }
        out.push((1, "<span\{style}>\{value}</span>"))
      } else {
        out.push((1, "<span class=\"hll\">\{value}</span>"))
      }
    } else {
      out.push((1, value))
    }
  }
  out
}

///|
/// Python's `_wrap_full`. With `cssfile`, the CSS file itself is not
/// written (see `cssfile_contents`).
fn HtmlFormatter::wrap_full(
  self : HtmlFormatter,
  inner : Array[Piece],
) -> Array[Piece] {
  let encoding = self.base.encoding.unwrap_or("None")
  let header = if self.cssfile != "" {
    html_doc_header_externalcss(self.base.title, self.cssfile, encoding)
  } else {
    html_doc_header(self.base.title, self.get_style_defs(arg="body"), encoding)
  }
  let out = [(0, header)]
  out.append(inner)
  out.push((0, html_doc_footer))
  out
}

///|
/// Python's `format`: the HTML for `tokens`.
///
/// ```mbt check
/// test {
///   let f = @formatters.HtmlFormatter::new()
///   inspect(
///     f.format([(@token.keyword, "def"), (@token.text, " f\n")]),
///     content=(
///       #|<div class="highlight"><pre><span></span><span class="k">def</span> f
///       #|</pre></div>
///       #|
///     ),
///   )
/// }
/// ```
pub fn HtmlFormatter::format(
  self : HtmlFormatter,
  tokens : Tokens,
) -> String raise FormatterError {
  let mut source = self.format_lines(tokens)
  if !self.nowrap && self.linenos == 2 {
    source = self.wrap_inlinelinenos(source)
  }
  if self.hl_lines.length() > 0 {
    source = self.highlight_lines(source)
  }
  if !self.nowrap {
    if self.lineanchors != "" {
      source = self.wrap_lineanchors(source)
    }
    if self.linespans != "" {
      source = self.wrap_linespans(source)
    }
    if self.wrapcode {
      source = wrap_code(source)
    }
    source = self.wrap_pre(source)
    if self.linenos == 1 {
      source = self.wrap_tablelinenos(source)
    }
    source = self.wrap_div(source)
    if self.base.full {
      source = self.wrap_full(source)
    }
  }
  let buf = StringBuilder()
  for p in source {
    buf.write_string(p.1)
  }
  buf.to_string()
}
