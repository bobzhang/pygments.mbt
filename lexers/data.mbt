// Hand-written parts of pygments/lexers/data.py.

///|
/// `text[start:end]` on UTF-16 offsets.
fn data_sub(text : String, start : Int, end : Int) -> String {
  text.unsafe_substring(start~, end~)
}

///|
/// Python's `int(s)` for a string of ASCII digits.
fn data_parse_int(s : String) -> Int {
  let mut n = 0
  for c in s {
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  n
}

///|
fn yaml_tok_arg(args : Array[@lexer.CallbackArg], i : Int) -> @token.TokenType {
  match args[i] {
    Tok(t) => t
    _ => @token.text
  }
}

///|
fn yaml_bool_arg(args : Array[@lexer.CallbackArg], i : Int) -> Bool {
  match args[i] {
    Bool(b) => b
    _ => false
  }
}

///|
/// Callbacks of `YamlLexer`. The indentation state of Python's
/// `YamlLexerContext` is per-run state.
fn yaml_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let indent_stack : Array[Int] = []
  let indent = Ref(-1)
  let next_indent = Ref(0)
  let block_scalar_indent : Ref[Int?] = Ref(None)
  Map::from_array([
    (
      "YamlLexer.something",
      (ctx, m, args) => {
        let text = m.matched()
        if text == "" {
          return
        }
        ctx.emit(m.start(), yaml_tok_arg(args, 0), text)
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.reset_indent",
      (ctx, m, args) => {
        indent_stack.clear()
        indent.val = -1
        next_indent.val = 0
        block_scalar_indent.val = None
        ctx.emit(m.start(), yaml_tok_arg(args, 0), m.matched())
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.save_indent",
      (ctx, m, args) => {
        let start = yaml_bool_arg(args, 0)
        let token_class = yaml_tok_arg(args, 1)
        let mut text = m.matched()
        let mut extra = ""
        if start {
          next_indent.val = text.length()
          if next_indent.val < indent.val {
            while next_indent.val < indent.val {
              indent.val = indent_stack.pop().unwrap()
            }
            if next_indent.val > indent.val {
              extra = @lexer.py_slice(text, indent.val, text.length())
              text = @lexer.py_slice(text, 0, indent.val)
            }
          }
        } else {
          next_indent.val += text.length()
        }
        if text != "" {
          ctx.emit(m.start(), token_class, text)
        }
        if extra != "" {
          ctx.emit(m.start() + text.length(), token_class.sub("Error"), extra)
        }
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.set_indent",
      (ctx, m, args) => {
        let implicit = yaml_bool_arg(args, 0)
        let token_class = yaml_tok_arg(args, 1)
        let text = m.matched()
        if indent.val < next_indent.val {
          indent_stack.push(indent.val)
          indent.val = next_indent.val
        }
        if !implicit {
          next_indent.val += text.length()
        }
        ctx.emit(m.start(), token_class, text)
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.set_block_scalar_indent",
      (ctx, m, args) => {
        let text = m.matched()
        block_scalar_indent.val = None
        if text == "" {
          return
        }
        match m.group(1) {
          Some(increment) if increment != "" => {
            let current_indent = if indent.val > 0 { indent.val } else { 0 }
            block_scalar_indent.val = Some(
              current_indent + data_parse_int(increment),
            )
          }
          _ => ()
        }
        ctx.emit(m.start(), yaml_tok_arg(args, 0), text)
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.parse_block_scalar_empty_line",
      (ctx, m, args) => {
        let content_token_class = yaml_tok_arg(args, 0)
        let indent_token_class = yaml_tok_arg(args, 1)
        let text = m.matched()
        match block_scalar_indent.val {
          Some(bsi) if text.length() > bsi => {
            ctx.emit(m.start(), indent_token_class, data_sub(text, 0, bsi))
            ctx.emit(
              m.start() + bsi,
              content_token_class,
              data_sub(text, bsi, text.length()),
            )
          }
          _ => if text != "" { ctx.emit(m.start(), indent_token_class, text) }
        }
        ctx.pos = m.end()
      },
    ),
    (
      "YamlLexer.parse_block_scalar_indent",
      (ctx, m, args) => {
        let text = m.matched()
        match block_scalar_indent.val {
          None => {
            if text.length() <= (if indent.val > 0 { indent.val } else { 0 }) {
              ignore(ctx.stack.pop())
              ignore(ctx.stack.pop())
              return
            }
            block_scalar_indent.val = Some(text.length())
          }
          Some(bsi) =>
            if text.length() < bsi {
              ignore(ctx.stack.pop())
              ignore(ctx.stack.pop())
              return
            }
        }
        if text != "" {
          ctx.emit(m.start(), yaml_tok_arg(args, 0), text)
          ctx.pos = m.end()
        }
      },
    ),
    (
      "YamlLexer.parse_plain_scalar_indent",
      (ctx, m, args) => {
        let text = m.matched()
        if text.length() <= indent.val {
          ignore(ctx.stack.pop())
          ignore(ctx.stack.pop())
          return
        }
        if text != "" {
          ctx.emit(m.start(), yaml_tok_arg(args, 0), text)
          ctx.pos = m.end()
        }
      },
    ),
  ])
}

///|
/// `YamlLexer.get_tokens_unprocessed`: a fresh indentation context per run.
fn yaml_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    yaml_lexer_def.force(),
    text,
    stack,
    callbacks=yaml_lexer_callbacks(lx),
  )
}

///|
fn json_is_integer(c : Char) -> Bool {
  c == '-' || (c >= '0' && c <= '9')
}

///|
fn json_is_float(c : Char) -> Bool {
  c == '.' || c == 'e' || c == 'E' || c == '+'
}

///|
fn json_is_constant(c : Char) -> Bool {
  // set('truefalsenull')
  c is ('t' | 'r' | 'u' | 'e' | 'f' | 'a' | 'l' | 's' | 'n')
}

///|
fn json_is_hex(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn json_is_punctuation(c : Char) -> Bool {
  c is ('{' | '}' | '[' | ']' | ',')
}

///|
fn json_is_whitespace(c : Char) -> Bool {
  c is (' ' | '\n' | '\r' | '\t')
}

///|
/// `JsonLexer.get_tokens_unprocessed`: a hand-written state machine.
fn json_tokens(text : String) -> Array[@lexer.Token] {
  let out : Array[@lexer.Token] = []
  let queue : Array[@lexer.Token] = []
  let emit = (i : Int, t : @token.TokenType, v : String) => {
    out.push({ index: i, ttype: t, value: v, })
  }
  let flush = () => {
    out.append(queue)
    queue.clear()
  }
  let mut in_string = false
  let mut in_escape = false
  let mut in_unicode_escape = 0
  let mut in_whitespace = false
  let mut in_constant = false
  let mut in_number = false
  let mut in_float = false
  let mut in_punctuation = false
  let mut in_comment_single = false
  let mut in_comment_multiline = false
  let mut expecting_second_comment_opener = false
  let mut expecting_second_comment_closer = false
  let mut start = 0
  let n = text.length()
  let mut stop = 0
  while stop < n {
    let cu = text.unsafe_get(stop).to_int()
    // width of the code point starting here (Python iterates code points)
    let width = if cu >= 0xD800 &&
      cu <= 0xDBFF &&
      stop + 1 < n &&
      text.unsafe_get(stop + 1).to_int() >= 0xDC00 &&
      text.unsafe_get(stop + 1).to_int() <= 0xDFFF {
      2
    } else {
      1
    }
    let character = if width == 1 {
      Int::unsafe_to_char(cu)
    } else {
      '\u{FFFF}'
    }
    let next = stop + width
    if in_string {
      if in_unicode_escape > 0 {
        if json_is_hex(character) {
          in_unicode_escape -= 1
          if in_unicode_escape == 0 {
            in_escape = false
          }
        } else {
          in_unicode_escape = 0
          in_escape = false
        }
      } else if in_escape {
        if character == 'u' {
          in_unicode_escape = 4
        } else {
          in_escape = false
        }
      } else if character == '\\' {
        in_escape = true
      } else if character == '"' {
        queue.push({
          index: start,
          ttype: @token.string_double,
          value: data_sub(text, start, next),
        })
        in_string = false
        in_escape = false
        in_unicode_escape = 0
      }
      stop = next
      continue
    } else if in_whitespace {
      if json_is_whitespace(character) {
        stop = next
        continue
      }
      if queue.is_empty() {
        emit(start, @token.whitespace, data_sub(text, start, stop))
      } else {
        queue.push({
          index: start,
          ttype: @token.whitespace,
          value: data_sub(text, start, stop),
        })
      }
      in_whitespace = false
    } else if in_constant {
      if json_is_constant(character) {
        stop = next
        continue
      }
      emit(start, @token.keyword_constant, data_sub(text, start, stop))
      in_constant = false
    } else if in_number {
      if json_is_integer(character) {
        stop = next
        continue
      } else if json_is_float(character) {
        in_float = true
        stop = next
        continue
      }
      if in_float {
        emit(start, @token.number_float, data_sub(text, start, stop))
      } else {
        emit(start, @token.number_integer, data_sub(text, start, stop))
      }
      in_number = false
      in_float = false
    } else if in_punctuation {
      if json_is_punctuation(character) {
        stop = next
        continue
      }
      emit(start, @token.punctuation, data_sub(text, start, stop))
      in_punctuation = false
    } else if in_comment_single {
      if character != '\n' {
        stop = next
        continue
      }
      if queue.is_empty() {
        emit(start, @token.comment_single, data_sub(text, start, stop))
      } else {
        queue.push({
          index: start,
          ttype: @token.comment_single,
          value: data_sub(text, start, stop),
        })
      }
      in_comment_single = false
    } else if in_comment_multiline {
      if character == '*' {
        expecting_second_comment_closer = true
      } else if expecting_second_comment_closer {
        expecting_second_comment_closer = false
        if character == '/' {
          let tok : @lexer.Token = {
            index: start,
            ttype: @token.comment_multiline,
            value: data_sub(text, start, next),
          }
          if queue.is_empty() {
            out.push(tok)
          } else {
            queue.push(tok)
          }
          in_comment_multiline = false
        }
      }
      stop = next
      continue
    } else if expecting_second_comment_opener {
      expecting_second_comment_opener = false
      if character == '/' {
        in_comment_single = true
        stop = next
        continue
      } else if character == '*' {
        in_comment_multiline = true
        stop = next
        continue
      }
      flush()
      emit(start, @token.error, data_sub(text, start, stop))
    }
    start = stop
    if character == '"' {
      in_string = true
    } else if json_is_whitespace(character) {
      in_whitespace = true
    } else if character is ('f' | 'n' | 't') {
      flush()
      in_constant = true
    } else if json_is_integer(character) {
      flush()
      in_number = true
    } else if character == ':' {
      for t in queue {
        if t.ttype == @token.string_double {
          out.push({ ..t, ttype: @token.name_tag, })
        } else {
          out.push(t)
        }
      }
      queue.clear()
      in_punctuation = true
    } else if json_is_punctuation(character) {
      flush()
      in_punctuation = true
    } else if character == '/' {
      expecting_second_comment_opener = true
    } else {
      flush()
      emit(start, @token.error, data_sub(text, start, next))
    }
    stop = next
  }
  flush()
  let rest = data_sub(text, start, n)
  if in_string {
    emit(start, @token.error, rest)
  } else if in_float {
    emit(start, @token.number_float, rest)
  } else if in_number {
    emit(start, @token.number_integer, rest)
  } else if in_constant {
    emit(start, @token.keyword_constant, rest)
  } else if in_whitespace {
    emit(start, @token.whitespace, rest)
  } else if in_punctuation {
    emit(start, @token.punctuation, rest)
  } else if in_comment_single {
    emit(start, @token.comment_single, rest)
  } else if in_comment_multiline {
    emit(start, @token.error, rest)
  } else if expecting_second_comment_opener {
    emit(start, @token.error, rest)
  }
  out
}

///|
#warnings("-unused_error_type")
fn json_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  json_tokens(text)
}

///|
#warnings("-unused_error_type")
fn json_bare_object_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  json_tokens(text)
}

///|
let json_ld_keywords : Array[String] = [
  "base", "container", "context", "direction", "graph", "id", "import", "included",
  "index", "json", "language", "list", "nest", "none", "prefix", "propagate", "protected",
  "reverse", "set", "type", "value", "version", "vocab",
].map(k => "\"@\{k}\"")

///|
#warnings("-unused_error_type")
fn json_ld_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  json_tokens(text).map(t => {
    if t.ttype == @token.name_tag && json_ld_keywords.contains(t.value) {
      { ..t, ttype: @token.name_decorator, }
    } else {
      t
    }
  })
}
