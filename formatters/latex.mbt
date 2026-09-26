///|
/// Python's `latex.escape_tex`: escapes TeX special characters with
/// `\<commandprefix>Zxx{}` macros.
pub fn escape_tex(text : String, commandprefix : String) -> String {
  let cp = commandprefix
  let buf = StringBuilder()
  for c in text {
    let name = match c {
      '\\' => "Zbs"
      '{' => "Zob"
      '}' => "Zcb"
      '^' => "Zca"
      '_' => "Zus"
      '&' => "Zam"
      '<' => "Zlt"
      '>' => "Zgt"
      '#' => "Zsh"
      '%' => "Zpc"
      '$' => "Zdl"
      '-' => "Zhy"
      '\'' => "Zsq"
      '"' => "Zdq"
      '~' => "Zti"
      _ => {
        buf.write_char(c)
        continue
      }
    }
    buf.write_string("\\\{cp}\{name}{}")
  }
  buf.to_string()
}

///|
/// Metadata of Python's `LatexFormatter`.
pub let latex_info : FormatterInfo = {
  class_name: "LatexFormatter",
  name: "LaTeX",
  aliases: ["latex", "tex"],
  filenames: ["*.tex"],
  description: "Format tokens as LaTeX code. This needs the `fancyvrb` and `color` standard packages.",
}

///|
/// Python's `'%.2f' % (int(hex, 16) / 255.0)` for one color channel.
fn channel_ratio(hex2 : String) -> String {
  let v = parse_hex(hex2).unwrap_or(0)
  // round(v * 100 / 255) exactly: v / 255 is never a tie at two decimals
  let hundredths = (v * 200 + 255) / 510
  let whole = hundredths / 100
  let frac = hundredths % 100
  "\{whole}." + (if frac < 10 { "0" } else { "" }) + frac.to_string()
}

///|
/// Python's `rgbcolor` in `LatexFormatter._create_stylesheet`.
fn latex_rgbcolor(col : String?) -> String {
  match col {
    Some(c) if c != "" => {
      let part = (i : Int) => channel_ratio(@pystr.slice(c, i, end=i + 2))
      "\{part(0)},\{part(2)},\{part(4)}"
    }
    _ => "1,1,1"
  }
}

///|
/// Python's `LatexFormatter`: LaTeX `fancyvrb` output. Options: `style`,
/// `full`, `title`, `docclass`, `preamble`, `nowrap`, `linenos`,
/// `linenostart`, `linenostep`, `verboptions`, `commandprefix`,
/// `texcomments`, `mathescape`, `escapeinside`, `envname` (and
/// `nobackground`, which Python accepts but ignores).
pub struct LatexFormatter {
  base : BaseOptions
  nowrap : Bool
  docclass : String
  preamble : String
  linenos : Bool
  linenostart : Int
  linenostep : Int
  verboptions : String
  nobackground : Bool
  commandprefix : String
  texcomments : Bool
  mathescape : Bool
  escapeinside : String
  envname : String
  priv ttype2name : Map[@token.TokenType, String]
  priv cmd2def : Map[String, String]
}

///|
/// Creates a LaTeX formatter from `options`.
pub fn LatexFormatter::new(
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> LatexFormatter raise {
  let base = BaseOptions::new(options, style?)
  let escapeinside = options.get("escapeinside").unwrap_or("")
  let f : LatexFormatter = {
    base,
    nowrap: @lexer.get_bool_opt(options, "nowrap", false),
    docclass: options.get("docclass").unwrap_or("article"),
    preamble: options.get("preamble").unwrap_or(""),
    linenos: @lexer.get_bool_opt(options, "linenos", false),
    linenostart: abs_int_opt(options, "linenostart", 1),
    linenostep: abs_int_opt(options, "linenostep", 1),
    verboptions: options.get("verboptions").unwrap_or(""),
    nobackground: @lexer.get_bool_opt(options, "nobackground", false),
    commandprefix: options.get("commandprefix").unwrap_or("PY"),
    texcomments: @lexer.get_bool_opt(options, "texcomments", false),
    mathescape: @lexer.get_bool_opt(options, "mathescape", false),
    escapeinside: if escapeinside.char_length() == 2 {
      escapeinside
    } else {
      ""
    },
    envname: options.get("envname").unwrap_or("Verbatim"),
    ttype2name: Map([]),
    cmd2def: Map([]),
  }
  f.create_stylesheet()
  f
}

///|
/// Python's `_create_stylesheet`.
fn LatexFormatter::create_stylesheet(self : LatexFormatter) -> Unit {
  self.ttype2name[@token.token] = ""
  let cp = self.commandprefix
  for entry in self.base.style.iter() {
    let (ttype, ndef) = entry
    let name = @token.css_class(ttype)
    let d = StringBuilder()
    if ndef.bold {
      d.write_string("\\let\\$$@bf=\\textbf")
    }
    if ndef.italic {
      d.write_string("\\let\\$$@it=\\textit")
    }
    if ndef.underline {
      d.write_string("\\let\\$$@ul=\\underline")
    }
    if ndef.roman {
      d.write_string("\\let\\$$@ff=\\textrm")
    }
    if ndef.sans {
      d.write_string("\\let\\$$@ff=\\textsf")
    }
    if ndef.mono {
      d.write_string("\\let\\$$@ff=\\textsf")
    }
    if ndef.color is Some(_) {
      d.write_string(
        "\\def\\$$@tc##1{\\textcolor[rgb]{\{latex_rgbcolor(ndef.color)}}{##1}}",
      )
    }
    if ndef.border is Some(_) {
      d.write_string(
        "\\def\\$$@bc##1{{\\setlength{\\fboxsep}{\\string -\\fboxrule}\\fcolorbox[rgb]{\{latex_rgbcolor(ndef.border)}}{\{latex_rgbcolor(ndef.bgcolor)}}{\\strut ##1}}}",
      )
    } else if ndef.bgcolor is Some(_) {
      d.write_string(
        "\\def\\$$@bc##1{{\\setlength{\\fboxsep}{0pt}\\colorbox[rgb]{\{latex_rgbcolor(ndef.bgcolor)}}{\\strut ##1}}}",
      )
    }
    let cmndef = d.to_string()
    if cmndef == "" {
      continue
    }
    self.ttype2name[ttype] = name
    self.cmd2def[name] = cmndef.replace_all(old="$$", new=cp)
  }
}

///|
/// Python's `get_style_defs`: the macro definitions for the current style
/// (the argument is ignored).
pub fn LatexFormatter::get_style_defs(self : LatexFormatter) -> String {
  let cp = self.commandprefix
  let styles = []
  for name, definition in self.cmd2def {
    styles.push("\\@namedef{\{cp}@tok@\{name}}{\{definition}}")
  }
  percent_format(latex_style_template, { "cp": cp, "styles": styles.join("\n") })
}

///|
/// Python's `str.partition(sep)`.
fn partition(s : String, sep : String) -> (String, String, String) {
  match s.find(sep) {
    Some(i) =>
      (
        s.unsafe_substring(start=0, end=i),
        sep,
        s.unsafe_substring(start=i + sep.length(), end=s.length()),
      )
    None => (s, "", "")
  }
}

///|
/// Escapes the text of a comment token according to `texcomments`,
/// `mathescape` and `escapeinside`.
fn LatexFormatter::escape_comment(
  self : LatexFormatter,
  value : String,
) -> String {
  let cp = self.commandprefix
  if self.texcomments {
    // guess the comment starting lexeme and escape it, but nothing else
    let chars = value.to_array()
    let mut k = if chars.length() > 0 { 1 } else { 0 }
    while k < chars.length() && chars[k] == chars[0] {
      k += 1
    }
    let start = String::from_array(chars[0:k])
    let rest = String::from_array(chars[k:])
    escape_tex(start, cp) + rest
  } else if self.mathescape {
    let parts = @pystr.split(value, "$")
    let mut in_math = false
    for i in 0..<parts.length() {
      if !in_math {
        parts[i] = escape_tex(parts[i], cp)
      }
      in_math = !in_math
    }
    parts.join("$")
  } else if self.escapeinside != "" {
    let left = @pystr.slice(self.escapeinside, 0, end=1)
    let right = @pystr.slice(self.escapeinside, 1)
    let mut text = value
    let buf = StringBuilder()
    while text != "" {
      let (a, sep1, rest) = partition(text, left)
      text = rest
      if sep1 != "" {
        let (b, sep2, rest) = partition(text, right)
        text = rest
        if sep2 != "" {
          buf.write_string(escape_tex(a, cp) + b)
        } else {
          buf.write_string(escape_tex(a + sep1 + b, cp))
        }
      } else {
        buf.write_string(escape_tex(a, cp))
      }
    }
    buf.to_string()
  } else {
    escape_tex(value, cp)
  }
}

///|
/// Python's `format`: the LaTeX for `tokens`.
pub fn LatexFormatter::format(self : LatexFormatter, tokens : Tokens) -> String {
  let cp = self.commandprefix
  let buf = StringBuilder()
  if !self.nowrap {
    buf.write_string("\\begin{\{self.envname}}[commandchars=\\\\\\{\\}")
    if self.linenos {
      let start = self.linenostart
      let step = self.linenostep
      buf.write_string(",numbers=left")
      if start != 0 {
        buf.write_string(",firstnumber=\{start}")
      }
      if step != 0 {
        buf.write_string(",stepnumber=\{step}")
      }
    }
    if self.mathescape || self.texcomments || self.escapeinside != "" {
      buf.write_string(
        ",codes={\\catcode`\\$=3\\catcode`\\^=7\\catcode`\\_=8\\relax}",
      )
    }
    if self.verboptions != "" {
      buf.write_string("," + self.verboptions)
    }
    buf.write_string("]\n")
  }
  for tok in tokens {
    let (ttype, value) = tok
    let value = if ttype.is_subtype_of(@token.comment) {
      self.escape_comment(value)
    } else if !ttype.is_subtype_of(@token.escape) {
      escape_tex(value, cp)
    } else {
      value
    }
    let styles = []
    let mut t = ttype
    while t != @token.token {
      styles.push(self.ttype2name.get(t).unwrap_or(@token.css_class(t)))
      t = t.parent().unwrap_or(@token.token)
    }
    styles.rev_in_place()
    let styleval = styles.join("+")
    if styleval != "" {
      let spl = @pystr.split(value, "\n")
      for i in 0..<(spl.length() - 1) {
        if spl[i] != "" {
          buf.write_string("\\\{cp}{\{styleval}}{\{spl[i]}}")
        }
        buf.write_string("\n")
      }
      let last = spl[spl.length() - 1]
      if last != "" {
        buf.write_string("\\\{cp}{\{styleval}}{\{last}}")
      }
    } else {
      buf.write_string(value)
    }
  }
  if !self.nowrap {
    buf.write_string("\\end{\{self.envname}}\n")
  }
  if !self.base.full {
    return buf.to_string()
  }
  let encoding = self.base.encoding.unwrap_or("utf8")
  let encoding = match encoding.replace_all(old="-", new="_") {
    "utf_8" => "utf8"
    "latin_1" | "iso_8859_1" => "latin1"
    _ => encoding
  }
  percent_format(latex_doc_template, {
    "docclass": self.docclass,
    "preamble": self.preamble,
    "title": self.base.title,
    "encoding": encoding,
    "styledefs": self.get_style_defs(),
    "code": buf.to_string(),
  })
}

///|
/// Wraps the LaTeX formatter as a generic `Formatter`.
pub fn LatexFormatter::to_formatter(self : LatexFormatter) -> Formatter {
  Formatter::new(latex_info, self.base, tokens => self.format(tokens), style_defs=_ => {
    self.get_style_defs()
  })
}
