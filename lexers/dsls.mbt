// Hand-written parts of pygments/lexers/dsls.py.

///|
let rsl_scheme_re : @regex.Regex = @lexer.re(
  "scheme\\s*.*?=\\s*class\\s*type",
  flags=@regex.IGNORECASE,
)

///|
fn rsl_lexer_analyse(text : String) -> Double {
  if @lexer.search(rsl_scheme_re, text) {
    1.0
  } else {
    0.0
  }
}

///|
/// Python's `re.escape` for a single character.
fn snowball_re_escape(c : String) -> String {
  let buf = StringBuilder()
  for ch in c {
    if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') || ch == '_' {
      buf.write_char(ch)
    } else if ch.to_int() < 128 {
      buf.write_char('\\')
      buf.write_char(ch)
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// Callbacks of `SnowballLexer`. The string escape delimiters (Python
/// instance attributes `_start`/`_end`) are reset for every run.
fn snowball_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let start = Ref("'")
  let end = Ref("'")
  Map::from_array([
    (
      "SnowballLexer._stringescapes",
      (ctx, m, _) => {
        start.val = m.group(3).unwrap_or("")
        end.val = m.group(5).unwrap_or("")
        ctx.apply(
          ByGroups([
            Emit(@token.keyword_reserved),
            Emit(@token.whitespace),
            Emit(@token.string_escape),
            Emit(@token.whitespace),
            Emit(@token.string_escape),
          ]),
          m,
        )
      },
    ),
    (
      "SnowballLexer._string",
      (ctx, m, args) => {
        let do_string_first = args is [Bool(true), ..]
        let s = m.start()
        let text = m.matched()
        let string_re = @regex.compile(
          "([^" + snowball_re_escape(start.val) + "]*)(.)",
        )
        let escape_re = @regex.compile(
          "([^" + snowball_re_escape(end.val) + "]*)(.)",
        )
        let mut pos = 0
        let mut do_string = do_string_first
        let mut last_end = 0
        while pos < text.length() {
          if do_string {
            guard string_re.match_at(text, pos) is Some(sm) else {
              fail("AttributeError: no string match")
            }
            last_end = sm.end()
            ctx.emit(
              s + sm.start(group=1),
              @token.string_single,
              sm.group(1).unwrap_or(""),
            )
            if sm.group(2) is Some("'") {
              ctx.emit(s + sm.start(group=2), @token.string_single, "'")
              ctx.stack.pop() |> ignore
              break
            }
            ctx.emit(
              s + sm.start(group=2),
              @token.string_escape,
              sm.group(2).unwrap_or(""),
            )
            pos = sm.end()
          }
          guard escape_re.match_at(text, pos) is Some(em) else {
            fail("AttributeError: no escape match")
          }
          last_end = em.end()
          ctx.emit(s + em.start(), @token.string_escape, em.matched())
          if em.group(2) != Some(end.val) {
            ctx.stack[ctx.stack.length() - 1] = ctx.def.state("escape")
            break
          }
          pos = em.end()
          do_string = true
        }
        ctx.pos = s + last_end
      },
    ),
  ])
}

///|
/// `SnowballLexer.get_tokens_unprocessed`: resets the escape delimiters.
fn snowball_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    snowball_lexer_def.force(),
    text,
    stack,
    callbacks=snowball_lexer_callbacks(lx),
  )
}
