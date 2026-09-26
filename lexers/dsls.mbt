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
/// Callbacks of `SnowballLexer`. The string escape delimiters (Python
/// instance attributes reset by `get_tokens_unprocessed`) are per-run state.
fn snowball_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let start = Ref("'")
  let end = Ref("'")
  Map::from_array([
    (
      "SnowballLexer._string",
      (ctx, m, args) => {
        let do_string_first = yaml_bool_arg(args, 0)
        let s = m.start()
        let text = m.matched()
        let string_re = @regex.compile("([^\{mime_re_escape(start.val)}]*)(.)")
        let escape_re = @regex.compile("([^\{mime_re_escape(end.val)}]*)(.)")
        let budget = @lexer.budget()
        let mut pos = 0
        let mut do_string = do_string_first
        let mut last_end = 0
        while pos < text.length() {
          if do_string {
            guard string_re.match_at(text, pos, budget~) is Some(sm) else {
              fail("SnowballLexer._string: no match")
            }
            last_end = sm.end()
            ctx.emit(
              s + sm.start(group=1),
              @token.string_single,
              markup_group(sm, 1),
            )
            if markup_group(sm, 2) == "'" {
              ctx.emit(
                s + sm.start(group=2),
                @token.string_single,
                markup_group(sm, 2),
              )
              ignore(ctx.stack.pop())
              break
            }
            ctx.emit(
              s + sm.start(group=2),
              @token.string_escape,
              markup_group(sm, 2),
            )
            pos = sm.end()
          }
          guard escape_re.match_at(text, pos, budget~) is Some(em) else {
            fail("SnowballLexer._string: no match")
          }
          last_end = em.end()
          ctx.emit(s + em.start(), @token.string_escape, em.matched())
          if markup_group(em, 2) != end.val {
            ctx.stack[ctx.stack.length() - 1] = ctx.def.state("escape")
            break
          }
          pos = em.end()
          do_string = true
        }
        ctx.pos = s + last_end
      },
    ),
    (
      "SnowballLexer._stringescapes",
      (ctx, m, _) => {
        start.val = markup_group(m, 3)
        end.val = markup_group(m, 5)
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
  ])
}

///|
/// `SnowballLexer.get_tokens_unprocessed` resets the string escapes.
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
