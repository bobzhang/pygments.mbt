///|
/// Metadata of Python's `HtmlFormatter`.
pub let html_info : FormatterInfo = {
  class_name: "HtmlFormatter",
  name: "HTML",
  aliases: ["html"],
  filenames: ["*.html", "*.htm"],
  description: "Format tokens as HTML 4 ``<span>`` tags. By default, the content is enclosed in a ``<pre>`` tag, itself wrapped in a ``<div>`` tag (but see the `nowrap` option). The ``<div>``'s CSS class can be set by the `cssclass` option.",
}

///|
/// Python's `HtmlFormatter`. Every option of the Python class is supported
/// except `tagsfile` (needs the `ctags` module; rejected) and the writing of
/// `cssfile`: with `full` and `cssfile` the document links to the file, and
/// `cssfile_contents` returns the text Python would write to it.
pub struct HtmlFormatter {
  base : BaseOptions
  nowrap : Bool
  noclasses : Bool
  classprefix : String
  cssclass : String
  cssstyles : String
  prestyles : String
  cssfile : String
  noclobber_cssfile : Bool
  tagurlformat : String
  filename : String
  wrapcode : Bool
  debug_token_types : Bool
  /// 0: no line numbers, 1: `table`, 2: `inline`.
  linenos : Int
  linenostart : Int
  linenostep : Int
  linenospecial : Int
  nobackground : Bool
  lineseparator : String
  lineanchors : String
  linespans : String
  anchorlinenos : Bool
  hl_lines : Array[Int]
  priv ttype2class : Map[@token.TokenType, String]
  priv class2style : Map[String, (String, @token.TokenType, Int)]
  priv span_openers : Map[@token.TokenType, String]
}

///|
/// Creates an HTML formatter from `options` (see Python's documentation of
/// `HtmlFormatter` for the option names).
pub fn HtmlFormatter::new(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> HtmlFormatter raise {
  let base = BaseOptions::new(options, style?)
  let tagsfile = options.get("tagsfile").unwrap_or("")
  if tagsfile != "" {
    raise FormatterError(
      "The \"ctags\" package must to be installed to be able to use the \"tagsfile\" feature.",
    )
  }
  let linenos = match options.get("linenos") {
    Some("inline") => 2
    Some(v) if v != "" => 1
    _ => 0
  }
  let hl_lines = []
  for s in @lexer.get_list_opt(options, "hl_lines", []) {
    match py_int(s) {
      Some(n) => if !hl_lines.contains(n) { hl_lines.push(n) }
      None => ()
    }
  }
  let f : HtmlFormatter = {
    base,
    nowrap: @lexer.get_bool_opt(options, "nowrap", false),
    noclasses: @lexer.get_bool_opt(options, "noclasses", false),
    classprefix: options.get("classprefix").unwrap_or(""),
    cssclass: @pystr.html_escape(options.get("cssclass").unwrap_or("highlight")),
    cssstyles: @pystr.html_escape(options.get("cssstyles").unwrap_or("")),
    prestyles: options.get("prestyles").unwrap_or(""),
    cssfile: options.get("cssfile").unwrap_or(""),
    noclobber_cssfile: @lexer.get_bool_opt(options, "noclobber_cssfile", false),
    tagurlformat: options.get("tagurlformat").unwrap_or(""),
    filename: @pystr.html_escape(options.get("filename").unwrap_or("")),
    wrapcode: @lexer.get_bool_opt(options, "wrapcode", false),
    debug_token_types: @lexer.get_bool_opt(options, "debug_token_types", false),
    linenos,
    linenostart: abs_int_opt(options, "linenostart", 1),
    linenostep: abs_int_opt(options, "linenostep", 1),
    linenospecial: abs_int_opt(options, "linenospecial", 0),
    nobackground: @lexer.get_bool_opt(options, "nobackground", false),
    lineseparator: @pystr.html_escape(
      options.get("lineseparator").unwrap_or("\n"),
    ),
    lineanchors: @pystr.html_escape(options.get("lineanchors").unwrap_or("")),
    linespans: @pystr.html_escape(options.get("linespans").unwrap_or("")),
    anchorlinenos: @lexer.get_bool_opt(options, "anchorlinenos", false),
    hl_lines,
    ttype2class: Map([]),
    class2style: Map([]),
    span_openers: Map([]),
  }
  f.create_stylesheet()
  f
}

///|
/// Python's `_get_css_class`: the CSS class of `ttype` with `classprefix`.
fn HtmlFormatter::get_css_class(
  self : HtmlFormatter,
  ttype : @token.TokenType,
) -> String {
  let c = ttype_class(ttype)
  if c != "" {
    self.classprefix + c
  } else {
    ""
  }
}

///|
/// Python's `_get_css_classes`: the classes of `ttype` and its non-standard
/// ancestors.
fn HtmlFormatter::get_css_classes(
  self : HtmlFormatter,
  ttype : @token.TokenType,
) -> String {
  let mut cls = self.get_css_class(ttype)
  let mut t = ttype
  while !is_standard(t) {
    match t.parent() {
      Some(p) => t = p
      None => break
    }
    cls = self.get_css_class(t) + " " + cls
  }
  cls
}

///|
/// Python's `_get_css_inline_styles`: the class of the nearest ancestor of
/// `ttype` that has a style.
fn HtmlFormatter::get_css_inline_styles(
  self : HtmlFormatter,
  ttype : @token.TokenType,
) -> String {
  let mut t = ttype
  while true {
    match self.ttype2class.get(t) {
      Some(c) => return c
      None =>
        match t.parent() {
          Some(p) => t = p
          None => return ""
        }
    }
  }
  ""
}

///|
/// Python's `_create_stylesheet`.
fn HtmlFormatter::create_stylesheet(self : HtmlFormatter) -> Unit {
  self.ttype2class[@token.token] = ""
  for entry in self.base.style.iter() {
    let (ttype, ndef) = entry
    let name = self.get_css_class(ttype)
    let style = StringBuilder()
    if ndef.color is Some(c) {
      style.write_string("color: \{webify(c)}; ")
    }
    if ndef.bold {
      style.write_string("font-weight: bold; ")
    }
    if ndef.italic {
      style.write_string("font-style: italic; ")
    }
    if ndef.underline {
      style.write_string("text-decoration: underline; ")
    }
    if ndef.bgcolor is Some(c) {
      style.write_string("background-color: \{webify(c)}; ")
    }
    if ndef.border is Some(c) {
      style.write_string("border: 1px solid \{webify(c)}; ")
    }
    let style = style.to_string()
    if style != "" {
      self.ttype2class[ttype] = name
      self.class2style[name] = (
        style.unsafe_substring(start=0, end=style.length() - 2),
        ttype,
        ttype_tuple(ttype).length(),
      )
    }
  }
}

///|
/// Python's `get_style_defs(arg)` (`arg` omitted is Python's `None`).
pub fn HtmlFormatter::get_style_defs(
  self : HtmlFormatter,
  arg? : String,
) -> String {
  let args = match arg {
    Some(a) => Some([a])
    None => None
  }
  self.style_defs_impl(args, arg is Some(a) && a != "")
}

///|
/// Python's `get_style_defs` with a list of selectors: every rule is
/// prefixed by each of `args`.
pub fn HtmlFormatter::get_style_defs_for(
  self : HtmlFormatter,
  args : Array[String],
) -> String {
  self.style_defs_impl(Some(args), args.length() > 0)
}

///|
fn HtmlFormatter::style_defs_impl(
  self : HtmlFormatter,
  args : Array[String]?,
  arg_truthy : Bool,
) -> String {
  let lines = self.get_linenos_style_defs()
  lines.append(self.background_style_defs(args, arg_truthy))
  lines.append(self.token_style_defs(args))
  lines.join("\n")
}

///|
/// Python's `get_css_prefix`: the function that prefixes a class with the
/// selectors `args` (`None` means the default, `.cssclass` if the
/// `cssclass` option was given).
fn HtmlFormatter::css_prefix(
  self : HtmlFormatter,
  args : Array[String]?,
) -> (String) -> String {
  let args = match args {
    Some(a) => a
    None =>
      if self.base.options.contains("cssclass") {
        ["." + self.cssclass]
      } else {
        [""]
      }
  }
  fn(cls : String) {
    let cls = if cls != "" { "." + cls } else { cls }
    args.map(a => (if a != "" { a + " " } else { "" }) + cls).join(", ")
  }
}

///|
/// Python's `get_css_prefix(arg)` applied to `cls`.
pub fn HtmlFormatter::get_css_prefix(
  self : HtmlFormatter,
  cls : String,
  arg? : String,
) -> String {
  let args = match arg {
    Some(a) => Some([a])
    None => None
  }
  self.css_prefix(args)(cls)
}

///|
/// Python's `get_token_style_defs(arg)`.
pub fn HtmlFormatter::get_token_style_defs(
  self : HtmlFormatter,
  arg? : String,
) -> Array[String] {
  self.token_style_defs(
    match arg {
      Some(a) => Some([a])
      None => None
    },
  )
}

///|
fn HtmlFormatter::token_style_defs(
  self : HtmlFormatter,
  args : Array[String]?,
) -> Array[String] {
  let prefix = self.css_prefix(args)
  let styles = []
  for cls, v in self.class2style {
    let (style, ttype, level) = v
    if cls != "" && style != "" {
      styles.push((level, ttype, cls, style))
    }
  }
  styles.sort_by((a, b) => {
    if a.0 != b.0 {
      return a.0 - b.0
    }
    let c = ttype_compare(a.1, b.1)
    if c != 0 {
      return c
    }
    let c = py_str_compare(a.2, b.2)
    if c != 0 {
      return c
    }
    py_str_compare(a.3, b.3)
  })
  styles.map(s => "\{prefix(s.2)} { \{s.3} } /* \{ttype_repr_tail(s.1)} */")
}

///|
/// Python's `get_token_style_defs` with a list of selectors.
pub fn HtmlFormatter::get_token_style_defs_for(
  self : HtmlFormatter,
  args : Array[String],
) -> Array[String] {
  self.token_style_defs(Some(args))
}

///|
/// Python's `get_background_style_defs` with a list of selectors.
pub fn HtmlFormatter::get_background_style_defs_for(
  self : HtmlFormatter,
  args : Array[String],
) -> Array[String] {
  self.background_style_defs(Some(args), args.length() > 0)
}

///|
/// Python's `get_background_style_defs(arg)`.
pub fn HtmlFormatter::get_background_style_defs(
  self : HtmlFormatter,
  arg? : String,
) -> Array[String] {
  match arg {
    Some(a) => self.background_style_defs(Some([a]), a != "")
    None => self.background_style_defs(None, false)
  }
}

///|
fn HtmlFormatter::background_style_defs(
  self : HtmlFormatter,
  args : Array[String]?,
  arg_truthy : Bool,
) -> Array[String] {
  let prefix = self.css_prefix(args)
  let lines = []
  if arg_truthy && !self.nobackground {
    match self.base.style.background_color {
      Some(bg) => {
        let text_style = match self.ttype2class.get(@token.text) {
          Some(c) =>
            match self.class2style.get(c) {
              Some(s) => " " + s.0
              None => ""
            }
          None => ""
        }
        lines.push("\{prefix("")}{ background: \{bg};\{text_style} }")
      }
      None => ()
    }
  }
  match self.base.style.highlight_color {
    Some(hl) => lines.insert(0, "\{prefix("hll")} { background-color: \{hl} }")
    None => ()
  }
  lines
}

///|
/// Python's `get_linenos_style_defs`.
pub fn HtmlFormatter::get_linenos_style_defs(
  self : HtmlFormatter,
) -> Array[String] {
  [
    "pre { \{pre_style} }",
    "td.linenos .normal { \{self.linenos_style()} }",
    "span.linenos { \{self.linenos_style()} }",
    "td.linenos .special { \{self.linenos_special_style()} }",
    "span.linenos.special { \{self.linenos_special_style()} }",
  ]
}

///|
/// Python's `_pre_style`.
let pre_style : String = "line-height: 125%;"

///|
/// Python's `_linenos_style`.
fn HtmlFormatter::linenos_style(self : HtmlFormatter) -> String {
  let st = self.base.style
  "color: \{st.line_number_color}; background-color: \{st.line_number_background_color}; padding-left: 5px; padding-right: 5px;"
}

///|
/// Python's `_linenos_special_style`.
fn HtmlFormatter::linenos_special_style(self : HtmlFormatter) -> String {
  let st = self.base.style
  "color: \{st.line_number_special_color}; background-color: \{st.line_number_special_background_color}; padding-left: 5px; padding-right: 5px;"
}

///|
/// The text Python writes to `cssfile` when `full` and `cssfile` are given
/// (this port does not write files; see `noclobber_cssfile`).
pub fn HtmlFormatter::cssfile_contents(self : HtmlFormatter) -> String {
  cssfile_template(self.get_style_defs(arg="body"))
}

///|
/// Wraps the HTML formatter as a generic `Formatter`.
pub fn HtmlFormatter::to_formatter(self : HtmlFormatter) -> Formatter {
  Formatter::new(html_info, self.base, tokens => self.format(tokens), style_defs=arg => {
    self.get_style_defs(arg?)
  })
}
