// Hand-written parts of pygments/lexers/haxe.py.

///|
/// Callbacks of `HaxeLexer` (an `ExtendedRegexLexer`). Python keeps the
/// saved state stacks of `#if` blocks in a class attribute; here they are
/// per-run state.
fn haxe_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let preproc_stack : Array[Array[String]] = []
  Map::from_array([
    (
      "HaxeLexer.preproc_callback",
      (ctx, m, _) => {
        let proc = m.group(2).unwrap_or("")
        match proc {
          // store the current stack
          "if" => preproc_stack.push(ctx.state_stack())
          // restore the stack back to right before #if
          "else" | "elseif" =>
            if preproc_stack.last() is Some(saved) {
              ctx.set_state_stack(saved)
            }
          // remove the saved stack of previous #if
          "end" => ignore(preproc_stack.pop())
          _ => ()
        }
        // #if and #elseif should follow by an expr
        if proc == "if" || proc == "elseif" {
          ctx.push_state("preproc-expr")
        }
        // #error can be optionally follow by the error msg
        if proc == "error" {
          ctx.push_state("preproc-error")
        }
        ctx.emit(m.start(), @token.comment_preproc, "#" + proc)
        ctx.pos = m.end()
      },
    ),
  ])
}

///|
let haxe_import_re : @regex.Regex = @lexer.re("\\bimport\\s+haxe\\.")

///|
let haxe_std_re : @regex.Regex = @lexer.re("\\bStd\\.")

///|
let haxe_trace_re : @regex.Regex = @lexer.re("\\btrace\\s*\\(")

///|
fn haxe_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(haxe_import_re, text) {
    rv = if rv > 0.2 { rv } else { 0.2 }
  }
  if @lexer.search(haxe_std_re, text) {
    rv = if rv > 0.1 { rv } else { 0.1 }
  }
  if @lexer.search(haxe_trace_re, text) {
    rv = if rv > 0.05 { rv } else { 0.05 }
  }
  rv
}
