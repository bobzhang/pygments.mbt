// Hand-written parts of pygments/lexers/markup.py.

///|
/// `match.group(i)` treating a non-participating group as `""`.
fn markup_group(m : @regex.Match, i : Int) -> String {
  m.group(i).unwrap_or("")
}

///|
/// Index of the named group `name` (the pattern is known to define it).
fn markup_gi(m : @regex.Match, name : String) -> Int {
  m.name_index(name).unwrap()
}

///|
/// Python's `str.strip()` (whitespace as defined by `str.isspace`).
fn markup_strip(s : String) -> String {
  let chars = s.to_array()
  let mut a = 0
  let mut b = chars.length()
  while a < b && @lexer.is_space(chars[a]) {
    a += 1
  }
  while b > a && @lexer.is_space(chars[b - 1]) {
    b -= 1
  }
  String::from_array(chars[a:b])
}

///|
/// Python's `str.splitlines(True)`.
fn markup_splitlines_keepends(s : String) -> Array[String] {
  let out = []
  let n = s.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    let c = s.unsafe_get(i).to_int()
    let is_break = c == 0x0a ||
      c == 0x0d ||
      c == 0x0b ||
      c == 0x0c ||
      (c >= 0x1c && c <= 0x1e) ||
      c == 0x85 ||
      c == 0x2028 ||
      c == 0x2029
    if is_break {
      let mut e = i + 1
      if c == 0x0d && e < n && s.unsafe_get(e) == '\n' {
        e += 1
      }
      out.push(s.unsafe_substring(start~, end=e))
      start = e
      i = e
    } else {
      i += 1
    }
  }
  if start < n {
    out.push(s.unsafe_substring(start~, end=n))
  }
  out
}

///|
/// Python's `s.find(sub, start)` on UTF-16 offsets.
fn markup_find_from(s : String, sub : String, start : Int) -> Int {
  if start > s.length() {
    return -1
  }
  match s.unsafe_substring(start~, end=s.length()).find(sub) {
    Some(i) => start + i
    None => -1
  }
}

///|
/// Emits `tokens` shifted by `offset` (Python's `_shift_indices`).
fn markup_emit_shifted(
  ctx : @lexer.Ctx,
  tokens : Array[@lexer.Token],
  offset : Int,
) -> Unit {
  for t in tokens {
    ctx.emit(t.index + offset, t.ttype, t.value)
  }
}

///|
fn rst_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let handlecodeblocks = @lexer.get_bool_opt(
    lx.options,
    "handlecodeblocks",
    true,
  )
  Map::from_array([
    (
      "RstLexer._handle_sourcecode",
      (ctx, m, _) => {
        let types = [
          @token.punctuation, @token.text, @token.operator_word, @token.punctuation,
          @token.text, @token.keyword, @token.text,
        ]
        for i, t in types {
          ctx.emit(m.start(group=i + 1), t, markup_group(m, i + 1))
        }
        let lexer = if handlecodeblocks {
          late_lexer_by_name(markup_strip(markup_group(m, 6)))
        } else {
          None
        }
        let indention = markup_group(m, 8)
        let indention_size = indention.length()
        let code = indention +
          markup_group(m, 9) +
          markup_group(m, 10) +
          markup_group(m, 11)
        guard lexer is Some(lexer) else {
          ctx.emit(m.start(group=8), @token.string, code)
        }
        let ins : Array[(Int, Array[@lexer.Token])] = []
        let buf = StringBuilder()
        let mut code_len = 0
        for line in markup_splitlines_keepends(code) {
          if line.length() > indention_size {
            ins.push(
              (
                code_len,
                [
                  {
                    index: 0,
                    ttype: @token.text,
                    value: line.unsafe_substring(start=0, end=indention_size),
                  },
                ],
              ),
            )
            let rest = line.unsafe_substring(
              start=indention_size,
              end=line.length(),
            )
            buf.write_string(rest)
            code_len += rest.length()
          } else {
            buf.write_string(line)
            code_len += line.length()
          }
        }
        markup_emit_shifted(
          ctx,
          @lexer.do_insertions(
            ins,
            lexer.get_tokens_unprocessed(buf.to_string()),
          ),
          m.start(group=8),
        )
      },
    ),
  ])
}

///|
/// `RstLexer.__init__` reads the `handlecodeblocks` option.
fn rst_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    rst_lexer_def.force(),
    text,
    stack,
    callbacks=rst_lexer_callbacks(lx),
  )
}

///|
fn rst_lexer_analyse(text : String) -> Double {
  let chars = text.to_array()
  let n = chars.length()
  if n >= 2 && chars[0] == '.' && chars[1] == '.' && (n < 3 || chars[2] != '.') {
    return 0.3
  }
  let find = (c : Char, from : Int) => {
    let mut i = if from < 0 { 0 } else { from }
    while i < n {
      if chars[i] == c {
        return i
      }
      i += 1
    }
    -1
  }
  let p1 = find('\n', 0)
  let p2 = find('\n', p1 + 1)
  if p2 > -1 &&
    p1 * 2 + 1 == p2 &&
    (chars[p1 + 1] == '-' || chars[p1 + 1] == '=') &&
    chars[p1 + 1] == chars[p2 - 1] {
    return 0.5
  }
  0.0
}

///|
fn tex_lexer_analyse(text : String) -> Double {
  for start in ["\\documentclass", "\\input", "\\documentstyle", "\\relax"] {
    if text.has_prefix(start) {
      return 1.0
    }
  }
  0.0
}

///|
let groff_alnum_re : @regex.Regex = @lexer.re("[^\\W_]+\\Z")

///|
fn groff_lexer_analyse(text : String) -> Double {
  if !text.has_prefix(".") {
    return 0.0
  }
  if text.has_prefix(".\\\"") {
    return 1.0
  }
  if text.has_prefix(".TH ") {
    return 1.0
  }
  let chars = text.to_array()
  // text starts with "." so it has at least one code point
  let mid = String::from_array(
    chars[1:if chars.length() < 3 { chars.length() } else { 3 }],
  )
  if @lexer.matches(groff_alnum_re, mid) {
    // text[3] raises IndexError on short input (an analyse error means 0.0)
    if chars.length() <= 3 {
      return 0.0
    }
    if @lexer.is_space(chars[3]) {
      return 0.9
    }
  }
  0.0
}

///|
fn markdown_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let handlecodeblocks = @lexer.get_bool_opt(
    lx.options,
    "handlecodeblocks",
    true,
  )
  Map::from_array([
    (
      "MarkdownLexer._handle_codeblock",
      (ctx, m, _) => {
        let g = (name : String) => markup_group(m, markup_gi(m, name))
        let s = (name : String) => m.start(group=markup_gi(m, name))
        ctx.emit(s("initial"), @token.string_backtick, g("initial"))
        ctx.emit(s("lang"), @token.string_backtick, g("lang"))
        if m.group(markup_gi(m, "afterlang")) is Some(_) {
          ctx.emit(s("whitespace"), @token.whitespace, g("whitespace"))
          ctx.emit(s("extra"), @token.text, g("extra"))
        }
        ctx.emit(s("newline"), @token.whitespace, g("newline"))
        let lexer = if handlecodeblocks {
          late_lexer_by_name(markup_strip(g("lang")))
        } else {
          None
        }
        let code = g("code")
        match lexer {
          None => ctx.emit(s("code"), @token.string, code)
          Some(lexer) =>
            markup_emit_shifted(
              ctx,
              lexer.get_tokens_unprocessed(code),
              s("code"),
            )
        }
        ctx.emit(s("terminator"), @token.string_backtick, g("terminator"))
      },
    ),
  ])
}

///|
/// `MarkdownLexer.__init__` reads the `handlecodeblocks` option.
fn markdown_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    markdown_lexer_def.force(),
    text,
    stack,
    callbacks=markdown_lexer_callbacks(lx),
  )
}

///|
fn tiddly_wiki5_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let handlecodeblocks = @lexer.get_bool_opt(
    lx.options,
    "handlecodeblocks",
    true,
  )
  Map::from_array([
    (
      "TiddlyWiki5Lexer._handle_codeblock",
      (ctx, m, _) => {
        ctx.emit(m.start(group=1), @token.string, markup_group(m, 1))
        ctx.emit(m.start(group=2), @token.string, markup_group(m, 2))
        ctx.emit(m.start(group=3), @token.text, markup_group(m, 3))
        let lexer = if handlecodeblocks {
          late_lexer_by_name(markup_strip(markup_group(m, 2)))
        } else {
          None
        }
        let code = markup_group(m, 4)
        guard lexer is Some(lexer) else {
          ctx.emit(m.start(group=4), @token.string, code)
        }
        markup_emit_shifted(
          ctx,
          lexer.get_tokens_unprocessed(code),
          m.start(group=4),
        )
        ctx.emit(m.start(group=5), @token.string, markup_group(m, 5))
      },
    ),
    (
      "TiddlyWiki5Lexer._handle_cssblock",
      (ctx, m, _) => {
        ctx.emit(m.start(group=1), @token.string, markup_group(m, 1))
        ctx.emit(m.start(group=2), @token.string, markup_group(m, 2))
        let lexer = if handlecodeblocks {
          late_lexer_by_name("css")
        } else {
          None
        }
        let code = markup_group(m, 3)
        guard lexer is Some(lexer) else {
          ctx.emit(m.start(group=3), @token.string, code)
        }
        markup_emit_shifted(
          ctx,
          lexer.get_tokens_unprocessed(code),
          m.start(group=3),
        )
        ctx.emit(m.start(group=4), @token.string, markup_group(m, 4))
      },
    ),
  ])
}

///|
/// `TiddlyWiki5Lexer.__init__` reads the `handlecodeblocks` option.
fn tiddly_wiki5_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    tiddly_wiki5_lexer_def.force(),
    text,
    stack,
    callbacks=tiddly_wiki5_lexer_callbacks(lx),
  )
}

///|
let wikitext_lang_re : @regex.Regex = @lexer.re("\\blang=(\"|'|)(\\w+)(\\1)")

///|
/// Shared start of `handle_syntaxhighlight` / `handle_score`: splits the tag
/// attributes from the content. Returns `None` (after lexing everything as
/// attributes) when there is no tag end. In a `RegexLexer`, `bygroups` hands
/// the callback a pseudo match of group 3, so `match.start(...)` is the
/// group start; the attribute tokens are not re-based (as in Python).
fn wikitext_split_tag(
  ctx : @lexer.Ctx,
  m : @regex.Match,
) -> (String, String, Int)? raise {
  let attr_content = m.matched()
  let mut start = 0
  let mut index = 0
  while true {
    index = markup_find_from(attr_content, ">", start)
    if @lexer.py_slice(attr_content, index - 2, index) != "--" {
      break
    }
    start = index + 1
  }
  if index == -1 {
    ctx.emit_lexed(ctx.lexer, attr_content, 0, stack=["root", "attr"])
    return None
  }
  let attr = attr_content.unsafe_substring(start=0, end=index)
  ctx.emit_lexed(ctx.lexer, attr, 0, stack=["root", "attr"])
  ctx.emit(m.start() + index, @token.punctuation, ">")
  let content = attr_content.unsafe_substring(
    start=index + 1,
    end=attr_content.length(),
  )
  Some((attr, content, index))
}

///|
/// The language of the last `lang=...` attribute, if any.
fn wikitext_lang(attr : String) -> String? raise {
  let ms = wikitext_lang_re.find_all(attr)
  if ms.is_empty() {
    None
  } else {
    ms[ms.length() - 1].group(2)
  }
}

///|
fn wikitext_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "WikitextLexer.handle_syntaxhighlight",
      (ctx, m, _) => {
        guard wikitext_split_tag(ctx, m) is Some((attr, content, index)) else {
          return
        }
        let lexer = match wikitext_lang(attr) {
          Some(lang) => late_lexer_by_name(lang)
          None => None
        }
        match lexer {
          None => ctx.emit(m.start() + index + 1, @token.text, content)
          Some(lexer) => ctx.emit_lexed(lexer, content, 0)
        }
      },
    ),
    (
      "WikitextLexer.handle_score",
      (ctx, m, _) => {
        guard wikitext_split_tag(ctx, m) is Some((attr, content, index)) else {
          return
        }
        let lang = wikitext_lang(attr).unwrap_or("lilypond")
        if lang == "lilypond" {
          ctx.emit_lexed(lily_pond_lexer(), content, 0)
        } else {
          ctx.emit(m.start() + index + 1, @token.text, content)
        }
      },
    ),
  ])
}
