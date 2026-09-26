// Hand-written parts of pygments/lexers/configs.py.
// pydata: singularity_section_pattern = L.configs.SingularityLexer._section[1:]

///|
/// The first `n` code points of `text` (Python's `text[:n]`).
fn configs_prefix(text : String, n : Int) -> String {
  let mut i = 0
  let mut count = 0
  while i < text.length() && count < n {
    let c = text.unsafe_get(i).to_int()
    i += if c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length() { 2 } else { 1 }
    count += 1
  }
  text.unsafe_substring(start=0, end=i)
}

///|
let desktop_entry_re : @regex.Regex = @lexer.re(
  "^\\[Desktop Entry\\][ \\t]*$",
  flags=@regex.MULTILINE,
)

///|
fn desktop_lexer_analyse(text : String) -> Double {
  if text.has_prefix("[Desktop Entry]") {
    return 1.0
  }
  if @lexer.search(desktop_entry_re, configs_prefix(text, 500)) {
    return 0.9
  }
  0.0
}

///|
fn ini_lexer_analyse(text : String) -> Double {
  // npos is a code point index in Python
  let mut npos = -1
  let mut cp = 0
  let mut prev = '\u{0}'
  let mut first = '\u{0}'
  for c in text {
    if cp == 0 {
      first = c
    }
    if c == '\n' {
      npos = cp
      break
    }
    prev = c
    cp += 1
  }
  if npos < 3 {
    return 0.0
  }
  if first == '[' && prev == ']' {
    0.8
  } else {
    0.0
  }
}

///|
fn regedit_lexer_analyse(text : String) -> Double {
  if text.has_prefix("Windows Registry Editor") {
    1.0
  } else {
    0.0
  }
}

///|
let singularity_keyword_re : @regex.Regex = @lexer.re(
  "\\b(?:osversion|includecmd|mirrorurl)\\b",
  flags=@regex.IGNORECASE,
)

///|
let singularity_section_re : @regex.Regex = @lexer.re(
  singularity_section_pattern,
)

///|
fn singularity_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if @lexer.search(singularity_keyword_re, text) {
    result += 0.5
  }
  if @lexer.search(singularity_section_re, text) {
    result += 0.49
  }
  result
}

///|
let systemd_unit_re : @regex.Regex = @lexer.re(
  "^\\[Unit\\][ \\t]*$",
  flags=@regex.MULTILINE,
)

///|
fn systemd_lexer_analyse(text : String) -> Double {
  if text.has_prefix("[Unit]") {
    return 1.0
  }
  if @lexer.search(systemd_unit_re, configs_prefix(text, 500)) {
    return 0.9
  }
  0.0
}

///|
/// `pygments.lexer.line_re`.
let configs_line_re : @regex.Regex = @lexer.re(".*?\\n")

///|
fn terraform_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "TerraformLexer.heredoc_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(group=1), @token.operator, markup_group(m, 1))
        ctx.emit(m.start(group=2), @token.string_delimiter, markup_group(m, 2))
        ctx.emit(m.start(group=3), @token.string_heredoc, markup_group(m, 3))
        ctx.pos = m.end()
        let hdname = markup_group(m, 2)
        let lines : Array[@regex.Match] = []
        let mut pos = ctx.pos
        let mut found = false
        while pos <= ctx.text.length() {
          guard configs_line_re.search(ctx.text, pos~, budget=@lexer.budget())
            is Some(lm) else {
            break
          }
          if markup_strip(lm.matched()) == hdname {
            for am in lines {
              ctx.emit(am.start(), @token.string_heredoc, am.matched())
            }
            ctx.emit(lm.start(), @token.string_delimiter, lm.matched())
            ctx.pos = lm.end()
            found = true
            break
          }
          lines.push(lm)
          pos = lm.end()
        }
        if !found {
          for am in lines {
            ctx.emit(am.start(), @token.error, am.matched())
          }
        }
      },
    ),
  ])
}
