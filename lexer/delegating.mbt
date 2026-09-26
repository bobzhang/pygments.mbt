///|
/// Python's `do_insertions`: inserts each token list of `insertions` at its
/// index into the stream `tokens`, splitting tokens as needed.
pub fn do_insertions(
  insertions : Array[(Int, Array[Token])],
  tokens : Array[Token],
) -> Array[Token] {
  let out = []
  if insertions.is_empty() {
    out.append(tokens)
    return out
  }
  let mut ins_i = 0
  let mut index = insertions[0].0
  let mut itokens = insertions[0].1
  let mut realpos : Int? = None
  let mut insleft = true
  for tok in tokens {
    let i = tok.index
    let t = tok.ttype
    let v = tok.value
    if realpos is None {
      realpos = Some(i)
    }
    let mut oldi = 0
    while insleft && i + v.length() >= index {
      let cut = index - i
      let tmpval = py_slice(v, oldi, cut)
      if tmpval != "" {
        let rp = realpos.unwrap()
        out.push({ index: rp, ttype: t, value: tmpval, })
        realpos = Some(rp + tmpval.length())
      }
      for it in itokens {
        let rp = realpos.unwrap()
        out.push({ index: rp, ttype: it.ttype, value: it.value, })
        realpos = Some(rp + it.value.length())
      }
      oldi = cut
      ins_i += 1
      if ins_i < insertions.length() {
        index = insertions[ins_i].0
        itokens = insertions[ins_i].1
      } else {
        insleft = false
        break
      }
    }
    if oldi < v.length() {
      let rest = py_slice(v, oldi, v.length())
      let rp = realpos.unwrap()
      out.push({ index: rp, ttype: t, value: rest, })
      realpos = Some(rp + v.length() - oldi)
    }
  }
  // leftover tokens
  while insleft {
    let mut rp = realpos.unwrap_or(0)
    for it in itokens {
      out.push({ index: rp, ttype: it.ttype, value: it.value, })
      rp += it.value.length()
    }
    realpos = Some(rp)
    ins_i += 1
    if ins_i < insertions.length() {
      index = insertions[ins_i].0
      itokens = insertions[ins_i].1
    } else {
      insleft = false
    }
  }
  out
}

///|
/// Python slicing `s[start:end]` with clamping (negative `end` counts from
/// the end, as in Python).
pub fn py_slice(s : String, start : Int, end : Int) -> String {
  let n = s.length()
  let clamp = (x : Int) => {
    if x < 0 {
      let y = n + x
      if y < 0 {
        0
      } else {
        y
      }
    } else if x > n {
      n
    } else {
      x
    }
  }
  let a = clamp(start)
  let b = clamp(end)
  if a >= b {
    ""
  } else {
    s.unsafe_substring(start=a, end=b)
  }
}

///|
/// Python's `DelegatingLexer.get_tokens_unprocessed`: lexes with `language`,
/// then lexes the concatenation of all `needle` tokens with `root` and
/// re-inserts the other language tokens.
pub fn delegate(
  root : Lexer,
  language : Lexer,
  text : String,
  needle? : @token.TokenType = @token.other,
) -> Array[Token] raise {
  let buffered = StringBuilder()
  let mut buffered_len = 0
  let insertions : Array[(Int, Array[Token])] = []
  let mut lng_buffer : Array[Token] = []
  for tok in language.get_tokens_unprocessed(text) {
    if tok.ttype == needle {
      if !lng_buffer.is_empty() {
        insertions.push((buffered_len, lng_buffer))
        lng_buffer = []
      }
      buffered.write_string(tok.value)
      buffered_len += tok.value.length()
    } else {
      lng_buffer.push(tok)
    }
  }
  if !lng_buffer.is_empty() {
    insertions.push((buffered_len, lng_buffer))
  }
  do_insertions(insertions, root.get_tokens_unprocessed(buffered.to_string()))
}
