// Hand-written parts of pygments/lexers/mime.py.

///|
/// Python's `re.escape`.
fn mime_re_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    match c {
      '('
      | ')'
      | '['
      | ']'
      | '{'
      | '}'
      | '?'
      | '*'
      | '+'
      | '-'
      | '|'
      | '^'
      | '$'
      | '\\'
      | '.'
      | '&'
      | '~'
      | '#'
      | ' '
      | '\t'
      | '\n'
      | '\r'
      | '\u{0b}'
      | '\u{0c}' => {
        sb.write_char('\\')
        sb.write_char(c)
      }
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Per-lexer state of `MIMELexer` (instance attributes set in `__init__`
/// and updated by the callbacks while lexing).
priv struct MimeState {
  mut boundary : String?
  mut content_transfer_encoding : String?
  mut content_type : String
  max_nested_level : Int
}

///|
/// `MIMELexer.get_bodypart_tokens`.
fn mime_bodypart_tokens(
  st : MimeState,
  text : String,
) -> Array[@lexer.Token] raise {
  let other : Array[@lexer.Token] = [
    { index: 0, ttype: @token.other, value: text, },
  ]
  if markup_strip(text) == "" || st.content_type == "" {
    return other
  }
  match st.content_transfer_encoding {
    Some(cte) if cte != "" &&
      !(cte == "8bit" || cte == "7bit" || cte == "quoted-printable") =>
      return other
    _ => ()
  }
  if st.max_nested_level == 0 {
    return other
  }
  guard late_lexer_for_mimetype(st.content_type) is Some(lexer) else {
    return other
  }
  let lexer = if lexer.info.class_name == "MIMELexer" {
    mime_lexer(options={
      "MIME-max-level": (st.max_nested_level - 1).to_string(),
    })
  } else {
    lexer
  }
  lexer.get_tokens_unprocessed(text)
}

///|
/// Callbacks of `MIMELexer`. Nested header values are lexed with the same
/// callbacks (Python calls `self.get_tokens_unprocessed`, sharing the
/// instance state).
fn mime_lexer_callbacks(
  lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] raise {
  let st : MimeState = {
    boundary: lx.options.get("Multipart-Boundary"),
    content_transfer_encoding: lx.options.get("Content_Transfer_Encoding"),
    content_type: lx.options.get("Content_Type").unwrap_or("text/plain"),
    max_nested_level: @lexer.get_int_opt(lx.options, "MIME-max-level", -1),
  }
  let cbs : Map[String, @lexer.CallbackFn] = Map([])
  cbs["MIMELexer.get_header_tokens"] = (ctx, m, _) => {
    let field = markup_group(m, 1)
    let lower = field.to_lower()
    if lower == "content-type" || lower == "content-transfer-encoding" {
      ctx.emit(m.start(group=1), @token.name_tag, field + ":")
      ctx.emit(m.start(group=2), @token.text_whitespace, markup_group(m, 2))
      let pos = m.end(group=2)
      let toks = @lexer.run_regex(
        ctx.lexer,
        mime_lexer_def.force(),
        markup_group(m, 3),
        ["root", lower],
        callbacks=cbs,
      )
      for t in toks {
        ctx.emit(pos + t.index, t.ttype, t.value)
      }
    } else {
      ctx.emit(m.start(), @token.comment, m.matched())
    }
  }
  cbs["MIMELexer.get_body_tokens"] = (ctx, m, _) => {
    let mut pos_body_start = m.start()
    let mut entire_body = m.matched()
    if entire_body.has_prefix("\n") {
      ctx.emit(pos_body_start, @token.text_whitespace, "\n")
      pos_body_start += 1
      entire_body = entire_body.unsafe_substring(
        start=1,
        end=entire_body.length(),
      )
    }
    let emit_part = (offset : Int, part : String) => {
      for t in mime_bodypart_tokens(st, part) {
        ctx.emit(offset + t.index, t.ttype, t.value)
      }
    }
    let boundary = match st.boundary {
      Some(b) if b != "" && st.content_type.has_prefix("multipart") => b
      _ => {
        emit_part(pos_body_start, entire_body)
        return
      }
    }
    let bdry = @regex.compile(
      "^--\{mime_re_escape(boundary)}(--)?\\n",
      flags=@regex.MULTILINE,
    )
    let mut pos_part_start = pos_body_start
    let mut pos_iter_start = 0
    match bdry.search(entire_body, budget=@lexer.budget()) {
      Some(bm) => {
        pos_part_start = pos_body_start + bm.end()
        pos_iter_start = bm.end()
        ctx.emit(
          pos_body_start,
          @token.text,
          entire_body.unsafe_substring(start=0, end=bm.start()),
        )
        ctx.emit(
          pos_body_start + bm.end(),
          @token.string_delimiter,
          bm.matched(),
        )
      }
      None => ()
    }
    let mut search_pos = pos_iter_start
    while search_pos <= entire_body.length() {
      guard bdry.search(entire_body, pos=search_pos, budget=@lexer.budget())
        is Some(bm) else {
        break
      }
      let lpos_start = pos_part_start - pos_body_start
      let lpos_end = bm.start()
      emit_part(
        pos_part_start,
        @lexer.py_slice(entire_body, lpos_start, lpos_end),
      )
      ctx.emit(pos_body_start + lpos_end, @token.string_delimiter, bm.matched())
      pos_part_start = pos_body_start + bm.end()
      search_pos = if bm.end() > bm.start() { bm.end() } else { bm.end() + 1 }
    }
    let lpos_start = pos_part_start - pos_body_start
    if lpos_start != entire_body.length() {
      ctx.emit(
        pos_part_start,
        @token.text,
        @lexer.py_slice(entire_body, lpos_start, entire_body.length()),
      )
    }
  }
  cbs["MIMELexer.store_content_type"] = (ctx, m, _) => {
    st.content_type = markup_group(m, 1)
    let prefix_len = m.start(group=1) - m.start()
    ctx.emit(
      m.start(),
      @token.text_whitespace,
      @lexer.py_slice(m.matched(), 0, prefix_len),
    )
    ctx.emit(m.start(group=1), @token.name_label, markup_group(m, 2))
    ctx.emit(m.end(group=2), @token.string_delimiter, "/")
    ctx.emit(m.start(group=3), @token.name_label, markup_group(m, 3))
  }
  cbs["MIMELexer.get_content_type_subtokens"] = (ctx, m, _) => {
    ctx.emit(m.start(group=1), @token.text, markup_group(m, 1))
    ctx.emit(m.start(group=2), @token.text_whitespace, markup_group(m, 2))
    ctx.emit(m.start(group=3), @token.name_attribute, markup_group(m, 3))
    ctx.emit(m.start(group=4), @token.operator, markup_group(m, 4))
    ctx.emit(m.start(group=5), @token.string, markup_group(m, 5))
    if markup_group(m, 3).to_lower() == "boundary" {
      let mut boundary = markup_strip(markup_group(m, 5))
      if boundary.has_prefix("\"") && boundary.has_suffix("\"") {
        boundary = @lexer.py_slice(boundary, 1, -1)
      }
      st.boundary = Some(boundary)
    }
  }
  cbs["MIMELexer.store_content_transfer_encoding"] = (ctx, m, _) => {
    st.content_transfer_encoding = Some(m.matched().to_lower())
    ctx.emit(m.start(), @token.name_constant, m.matched())
  }
  cbs
}

///|
/// `MIMELexer.__init__` reads the `MIME-max-level`, `Content_Type`,
/// `Multipart-Boundary` and `Content_Transfer_Encoding` options.
fn mime_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    mime_lexer_def.force(),
    text,
    stack,
    callbacks=mime_lexer_callbacks(lx),
  )
}
