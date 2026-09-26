///|
/// A formatter class: its metadata and constructor (`options`, optional
/// style overriding the `style` option).
pub type FormatterClass = (
  FormatterInfo,
  (@lexer.Options, @styles.Style?) -> Formatter raise,
)

///|
/// All formatters, in Python's `FORMATTERS` order. The PIL image formatters
/// `img`, `gif`, `jpg` and `bmp` are listed but raise when constructed.
let all_formatters : Array[FormatterClass] = [
  (bbcode_info, (o, s) => bbcode_formatter(options=o, style?=s)),
  (image_formatter_infos[0], image_formatter),
  (image_formatter_infos[1], image_formatter),
  (groff_info, (o, s) => groff_formatter(options=o, style?=s)),
  (html_info, (o, s) => HtmlFormatter::new(options=o, style?=s).to_formatter()),
  (irc_info, (o, s) => irc_formatter(options=o, style?=s)),
  (image_formatter_infos[2], image_formatter),
  (image_formatter_infos[3], image_formatter),
  (
    latex_info,
    (o, s) => LatexFormatter::new(options=o, style?=s).to_formatter(),
  ),
  (null_info, (o, s) => null_formatter(options=o, style?=s)),
  (pango_info, (o, s) => pango_markup_formatter(options=o, style?=s)),
  (raw_token_info, (o, s) => raw_token_formatter(options=o, style?=s)),
  (rtf_info, (o, s) => rtf_formatter(options=o, style?=s)),
  (svg_info, (o, s) => svg_formatter(options=o, style?=s)),
  (terminal256_info, (o, s) => terminal256_formatter(options=o, style?=s)),
  (terminal_info, (o, s) => terminal_formatter(options=o, style?=s)),
  (
    terminal_true_color_info,
    (o, s) => terminal_true_color_formatter(options=o, style?=s),
  ),
  (testcase_info, (o, s) => testcase_formatter(options=o, style?=s)),
]

///|
/// Python's `get_all_formatters`: metadata of every formatter.
pub fn get_all_formatters() -> Array[FormatterInfo] {
  all_formatters.map(c => c.0)
}

///|
/// Python's `find_formatter_class`: the formatter class with `alias`.
pub fn find_formatter_class(name : String) -> FormatterClass? {
  for c in all_formatters {
    if c.0.aliases.contains(name) {
      return Some(c)
    }
  }
  None
}

///|
/// Python's `get_formatter_by_name`: an instance of the formatter with
/// `alias`, configured with `options`.
///
/// ```mbt check
/// test {
///   let f = @formatters.get_formatter_by_name("html", options={ "nowrap": "true" })
///   inspect(
///     f.format([(@token.keyword, "if")]),
///     content="<span class=\"k\">if</span>\n",
///   )
/// }
/// ```
pub fn get_formatter_by_name(
  name : String,
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  match find_formatter_class(name) {
    Some(c) => (c.1)(options, style)
    None =>
      raise ClassNotFound("no formatter found for name \{@pystr.repr(name)}")
  }
}

///|
/// Python's `fnmatch.fnmatch` (case-sensitive; `*`, `?`, `[...]`).
fn fn_matches(name : Array[Char], pat : Array[Char], i : Int, j : Int) -> Bool {
  if j == pat.length() {
    return i == name.length()
  }
  match pat[j] {
    '*' => {
      for k = i; k <= name.length(); k = k + 1 {
        if fn_matches(name, pat, k, j + 1) {
          return true
        }
      }
      false
    }
    '?' => i < name.length() && fn_matches(name, pat, i + 1, j + 1)
    '[' => {
      let mut k = j + 1
      let negate = k < pat.length() && pat[k] == '!'
      if negate {
        k += 1
      }
      let first = k
      while k < pat.length() && (pat[k] != ']' || k == first) {
        k += 1
      }
      if k >= pat.length() {
        // no closing bracket: a literal '['
        return i < name.length() &&
          name[i] == '[' &&
          fn_matches(name, pat, i + 1, j + 1)
      }
      if i >= name.length() {
        return false
      }
      let c = name[i]
      let mut hit = false
      let mut m = first
      while m < k {
        if m + 2 < k && pat[m + 1] == '-' {
          if c >= pat[m] && c <= pat[m + 2] {
            hit = true
          }
          m += 3
        } else {
          if c == pat[m] {
            hit = true
          }
          m += 1
        }
      }
      hit != negate && fn_matches(name, pat, i + 1, k + 1)
    }
    ch =>
      i < name.length() && name[i] == ch && fn_matches(name, pat, i + 1, j + 1)
  }
}

///|
/// Python's `get_formatter_for_filename`: an instance of the formatter
/// whose file name patterns match the base name of `filename`.
///
/// ```mbt check
/// test {
///   inspect(
///     @formatters.get_formatter_for_filename("out/a.tex").name(),
///     content="LaTeX",
///   )
/// }
/// ```
pub fn get_formatter_for_filename(
  filename : String,
  options? : @lexer.Options = Map([]),
  style? : @styles.Style,
) -> Formatter raise {
  let base = match filename.rev_find("/") {
    Some(i) => filename.unsafe_substring(start=i + 1, end=filename.length())
    None => filename
  }
  let name = base.to_array()
  for c in all_formatters {
    for pat in c.0.filenames {
      if fn_matches(name, pat.to_array(), 0, 0) {
        return (c.1)(options, style)
      }
    }
  }
  raise ClassNotFound("no formatter found for file name \{@pystr.repr(base)}")
}
