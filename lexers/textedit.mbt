// Hand-written parts of pygments/lexers/textedit.py.
// pydata: vim_command_short = [p[0] for p in L._vim_builtins.command]
// pydata: vim_command_long = [p[1] for p in L._vim_builtins.command]
// pydata: vim_option_short = [p[0] for p in L._vim_builtins.option]
// pydata: vim_option_long = [p[1] for p in L._vim_builtins.option]
// pydata: vim_auto_short = [p[0] for p in L._vim_builtins.auto]
// pydata: vim_auto_long = [p[1] for p in L._vim_builtins.auto]

///|
/// Python's `<` on strings (code point order; all Vim keywords are ASCII).
fn vim_str_lt(a : String, b : String) -> Bool {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a.unsafe_get(i)
    let y = b.unsafe_get(i)
    if x != y {
      return x < y
    }
  }
  a.length() < b.length()
}

///|
/// Python's `s[:n]`.
fn vim_prefix(s : String, n : Int) -> String {
  @lexer.py_slice(s, 0, n)
}

///|
/// `VimLexer.is_in`: whether `w` is a valid abbreviation of one of the
/// `(short, long)` pairs of `mapping` (sorted, searched with `bisect`).
fn vim_is_in(w : String, short : Array[String], long : Array[String]) -> Bool {
  // bisect(mapping, (w,)): (w,) < (s, l) iff w <= s
  let mut lo = 0
  let mut hi = short.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if !vim_str_lt(short[mid], w) {
      hi = mid
    } else {
      lo = mid + 1
    }
  }
  let p = lo
  if p > 0 {
    let s = short[p - 1]
    if s == vim_prefix(w, s.length()) &&
      vim_prefix(long[p - 1], w.length()) == w {
      return true
    }
  }
  if p < short.length() {
    let s = short[p]
    return s == vim_prefix(w, s.length()) &&
      vim_prefix(long[p], w.length()) == w
  }
  false
}

///|
/// `VimLexer.get_tokens_unprocessed`: `Name.Other` words are keywords,
/// builtins or plain text depending on the abbreviation tables.
fn vim_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, vim_lexer_def.force(), text, stack).map(t => {
    if t.ttype != @token.name_other {
      t
    } else if vim_is_in(t.value, vim_command_short, vim_command_long) {
      { ..t, ttype: @token.keyword, }
    } else if vim_is_in(t.value, vim_option_short, vim_option_long) ||
      vim_is_in(t.value, vim_auto_short, vim_auto_long) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      { ..t, ttype: @token.text, }
    }
  })
}
