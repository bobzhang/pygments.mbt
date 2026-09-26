// Hand-written parts of pygments/lexers/maple.py.

///|
fn maple_lexer_analyse(text : String) -> Double {
  if text.contains(":=") {
    0.1
  } else {
    0.0
  }
}

///|
/// `MapleLexer.delayed_callback`: lexes the body of a delayed-evaluation
/// quote (`'...'`) with the same context, bounded to group 2.
fn maple_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  {
    "MapleLexer.delayed_callback": (ctx, m, _) => {
      let quote = m.group(1).unwrap_or("")
      ctx.emit(m.start(group=1), @token.punctuation, quote)
      ctx.pos = m.start(group=2)
      let orig_end = ctx.end
      ctx.end = m.end(group=2)
      @lexer.run_context(ctx)
      ctx.emit(m.end(group=2), @token.punctuation, quote)
      ctx.pos = m.end()
      ctx.end = orig_end
    },
  }
}
