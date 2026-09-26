// Hand-written parts of pygments/lexers/textfmts.py.

///|
let http_general_type_re : @regex.Regex = @lexer.re("^(.*)/.*\\+(.*)$")

///|
/// Callbacks of `HttpLexer`; the content type seen in the headers is
/// per-run state (reset by `get_tokens_unprocessed` in Python).
fn http_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let content_type : Ref[String?] = Ref(None)
  Map::from_array([
    (
      "HttpLexer.header_callback",
      (ctx, m, _) => {
        if markup_group(m, 1).to_lower() == "content-type" {
          let mut ct = markup_strip(markup_group(m, 5))
          match ct.find(";") {
            Some(i) => ct = markup_strip(ct.unsafe_substring(start=0, end=i))
            None => ()
          }
          content_type.val = Some(ct)
        }
        let types = [
          @token.name_attribute, @token.text, @token.operator, @token.text, @token.literal,
          @token.text,
        ]
        for i, t in types {
          ctx.emit(m.start(group=i + 1), t, markup_group(m, i + 1))
        }
      },
    ),
    (
      "HttpLexer.continuous_header_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(group=1), @token.text, markup_group(m, 1))
        ctx.emit(m.start(group=2), @token.literal, markup_group(m, 2))
        ctx.emit(m.start(group=3), @token.text, markup_group(m, 3))
      },
    ),
    (
      "HttpLexer.content_callback",
      (ctx, m, _) => {
        let content = m.matched()
        let offset = m.start()
        match content_type.val {
          Some(ct) if ct != "" => {
            let possible = [ct]
            if ct.contains("+") {
              possible.push(
                http_general_type_re.replace_all(ct, mm => {
                  markup_group(mm, 1) + "/" + markup_group(mm, 2)
                }),
              )
            }
            for mime in possible {
              if late_lexer_for_mimetype(mime) is Some(lexer) {
                ctx.emit_lexed(lexer, content, offset)
                return
              }
            }
          }
          _ => ()
        }
        ctx.emit(offset, @token.text, content)
      },
    ),
  ])
}

///|
/// `HttpLexer.get_tokens_unprocessed` resets the content type per run.
fn http_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    http_lexer_def.force(),
    text,
    stack,
    callbacks=http_lexer_callbacks(lx),
  )
}

///|
let http_request_re : @regex.Regex = @lexer.re(
  "^([a-zA-Z][-_a-zA-Z]+)( +)([^ ]+)( +)(HTTP)(/)(1\\.[01]|2(?:\\.0)?|3)(\\r?\\n|\\Z)",
)

///|
let http_response_re : @regex.Regex = @lexer.re(
  "^(HTTP)(/)(1\\.[01]|2(?:\\.0)?|3)( +)(\\d{3})(?:( +)([^\\r\\n]*))?(\\r?\\n|\\Z)",
)

///|
fn http_lexer_analyse(text : String) -> Double {
  if @lexer.search(http_request_re, text) ||
    @lexer.search(http_response_re, text) {
    1.0
  } else {
    0.0
  }
}

///|
fn notmuch_lexer_callbacks(lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let body_lexer = lx.options.get("body_lexer").unwrap_or("")
  Map::from_array([
    (
      "NotmuchLexer._highlight_code",
      (ctx, m, _) => {
        let code = markup_group(m, 1)
        let found = if body_lexer != "" {
          late_lexer_by_name(body_lexer)
        } else {
          late_guess_lexer(markup_strip(code))
        }
        let lexer = match found {
          Some(l) => l
          None => text_lexer()
        }
        ctx.emit_lexed(lexer, code, 0)
      },
    ),
  ])
}

///|
/// `NotmuchLexer.__init__` reads the `body_lexer` option.
fn notmuch_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    notmuch_lexer_def.force(),
    text,
    stack,
    callbacks=notmuch_lexer_callbacks(lx),
  )
}

///|
fn notmuch_lexer_analyse(text : String) -> Double {
  if text.has_prefix("\u{0c}message{") {
    1.0
  } else {
    0.0
  }
}
