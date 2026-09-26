// Hand-written parts of pygments/lexers/special.py.

///|
#warnings("-unused_error_type")
fn text_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.text_tokenizer(lx, text, stack)
}

///|
/// `TextLexer.analyse_text` returns the class priority.
fn text_lexer_analyse(_text : String) -> Double {
  0.01
}

///|
#warnings("-unused_error_type")
fn output_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  [{ index: 0, ttype: @token.generic_output, value: text, }]
}

///|
/// `RawTokenLexer`: recreates a token stream written by the
/// `RawTokenFormatter` (one `Token.Type<TAB>repr(value)` per line).
///
/// The `compress` option is validated as in Python, but gzip/bz2
/// decompression is not available: compressed input yields an `Error` token
/// followed by the (undecoded) input lexed as is, like Python's fallback for
/// undecompressable data.
fn raw_token_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let compress = @lexer.get_choice_opt(
    lx.options,
    "compress",
    ["", "none", "gz", "bz2"],
    "",
  )
  let out : Array[@lexer.Token] = []
  if compress == "gz" || compress == "bz2" {
    out.push({ index: 0, ttype: @token.error, value: text, })
  }
  let mut length = 0
  for entry in pystr_lines(text) {
    let line = entry.1
    let (ttype, val) = match raw_token_parse_line(line) {
      Some(tv) => tv
      None => (@token.error, line)
    }
    out.push({ index: length, ttype, value: val, })
    length += val.length()
  }
  out
}

///|
/// Parses one `RawTokenFormatter` line; `None` where Python raises
/// `SyntaxError`/`ValueError`.
fn raw_token_parse_line(line : String) -> (@token.TokenType, String)? {
  let stripped = line.trim_end(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
  guard stripped.find("\t") is Some(tab) else { return None }
  let ttypestr = stripped.unsafe_substring(start=0, end=tab)
  let valstr = stripped.unsafe_substring(start=tab + 1, end=stripped.length())
  let mut ttype = @token.token
  let parts = ttypestr.split(".").map(p => p.to_owned()).collect()
  for i in 1..<parts.length() {
    let p = parts[i]
    guard p.length() > 0 &&
      p.unsafe_get(0).to_int().unsafe_to_char() is ('A'..='Z') else {
      return None
    }
    ttype = ttype.sub(p)
  }
  match py_string_literal_eval(valstr) {
    Some(v) => Some((ttype, v))
    None => None
  }
}

///|
fn py_hex_value(s : String, start : Int, n : Int) -> Int? {
  if start + n > s.length() {
    return None
  }
  let mut v = 0
  for i in start..<(start + n) {
    let c = s.unsafe_get(i).to_int()
    let d = if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else if c >= 'a'.to_int() && c <= 'f'.to_int() {
      c - 'a'.to_int() + 10
    } else if c >= 'A'.to_int() && c <= 'F'.to_int() {
      c - 'A'.to_int() + 10
    } else {
      return None
    }
    v = v * 16 + d
  }
  Some(v)
}

///|
fn py_write_code_point(sb : StringBuilder, cp : Int) -> Bool {
  if cp < 0 || cp > 0x10FFFF {
    return false
  }
  sb.write_char(cp.unsafe_to_char())
  true
}

///|
/// `ast.literal_eval` restricted to (implicitly concatenated) `str`
/// literals, as written by `repr()`; `None` for anything else.
fn py_string_literal_eval(src : String) -> String? {
  let n = src.length()
  let sb = StringBuilder()
  let mut i = 0
  let mut count = 0
  let is_ws = (c : UInt16) => c == ' ' || c == '\t' || c == '\u{0c}'
  while true {
    while i < n && is_ws(src.unsafe_get(i)) {
      i += 1
    }
    if i >= n {
      break
    }
    // prefix
    let mut raw = false
    let c0 = src.unsafe_get(i)
    if c0 == 'r' || c0 == 'R' {
      raw = true
      i += 1
    } else if c0 == 'u' || c0 == 'U' {
      i += 1
    }
    if i >= n {
      return None
    }
    let q = src.unsafe_get(i)
    if q != '\'' && q != '"' {
      return None
    }
    let triple = i + 2 < n &&
      src.unsafe_get(i + 1) == q &&
      src.unsafe_get(i + 2) == q
    i += if triple { 3 } else { 1 }
    let mut closed = false
    while i < n {
      let c = src.unsafe_get(i)
      if c == q {
        if !triple {
          i += 1
          closed = true
          break
        } else if i + 2 < n &&
          src.unsafe_get(i + 1) == q &&
          src.unsafe_get(i + 2) == q {
          i += 3
          closed = true
          break
        }
        sb.write_char(c.to_int().unsafe_to_char())
        i += 1
        continue
      }
      if c == '\n' && !triple {
        return None
      }
      if c != '\\' {
        sb.write_char(c.to_int().unsafe_to_char())
        i += 1
        continue
      }
      if i + 1 >= n {
        return None
      }
      let e = src.unsafe_get(i + 1)
      if raw {
        sb.write_char('\\')
        sb.write_char(e.to_int().unsafe_to_char())
        i += 2
        continue
      }
      i += 2
      match e.to_int().unsafe_to_char() {
        '\n' => ()
        '\\' => sb.write_char('\\')
        '\'' => sb.write_char('\'')
        '"' => sb.write_char('"')
        'a' => sb.write_char('\u{07}')
        'b' => sb.write_char('\u{08}')
        'f' => sb.write_char('\u{0c}')
        'n' => sb.write_char('\n')
        'r' => sb.write_char('\r')
        't' => sb.write_char('\t')
        'v' => sb.write_char('\u{0b}')
        'x' | 'u' | 'U' as k => {
          let len = match k {
            'x' => 2
            'u' => 4
            _ => 8
          }
          guard py_hex_value(src, i, len) is Some(cp) else { return None }
          if !py_write_code_point(sb, cp) {
            return None
          }
          i += len
        }
        '0'..='7' as d => {
          let mut v = d.to_int() - '0'.to_int()
          let mut k = 0
          while k < 2 &&
                i < n &&
                src.unsafe_get(i) >= '0' &&
                src.unsafe_get(i) <= '7' {
            v = v * 8 + (src.unsafe_get(i).to_int() - '0'.to_int())
            i += 1
            k += 1
          }
          ignore(py_write_code_point(sb, v))
        }
        other => {
          sb.write_char('\\')
          sb.write_char(other)
        }
      }
    }
    if !closed {
      return None
    }
    count += 1
  }
  if count == 0 {
    None
  } else {
    Some(sb.to_string())
  }
}
