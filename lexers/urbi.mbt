// Hand-written parts of pygments/lexers/urbi.py.

///|
/// The UTF-16 offset `n` code points after `pos` (clamped to the text end).
fn urbi_advance(text : String, pos : Int, n : Int) -> Int {
  let mut i = pos
  let mut k = 0
  while k < n && i < text.length() {
    let c = text.unsafe_get(i).to_int()
    i += if c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length() { 2 } else { 1 }
    k += 1
  }
  i
}

///|
fn urbiscript_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "UrbiscriptLexer.blob_callback",
      (ctx, m, _) => {
        let text_before_blob = markup_group(m, 1)
        let blob_start = markup_group(m, 2)
        let blob_size_str = markup_group(m, 3)
        let blob_size = data_parse_int(blob_size_str)
        ctx.emit(m.start(), @token.string, text_before_blob)
        ctx.pos += text_before_blob.length()
        // Python indexes `ctx.text[match.end() + blob_size]` (an IndexError
        // past the end of the text); a missing ")" is treated as malformed
        let close = urbi_advance(ctx.text, m.end(), blob_size)
        let well_formed = close < ctx.text.length() &&
          ctx.text.unsafe_get(close) == ')'
        if !well_formed {
          let result = "\\B(" + blob_size_str + ")("
          ctx.emit(m.start(), @token.string, result)
          ctx.pos += result.length()
          return
        }
        let blob_text = blob_start +
          ctx.text.unsafe_substring(start=m.end(), end=close) +
          ")"
        ctx.emit(m.start(), @token.string_escape, blob_text)
        ctx.pos = close + 1
      },
    ),
  ])
}

///|
fn urbiscript_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("freezeif") {
    result += 0.05
  }
  if text.contains("waituntil") {
    result += 0.05
  }
  result
}
