// Hand-written parts of pygments/lexers/int_fiction.py.
// pydata: tads3_ws_pp = L.int_fiction.Tads3Lexer._ws_pp

///|
/// `Inform6Lexer.get_tokens_unprocessed`: `in` is a keyword when the token
/// two (non-comment, non-text) tokens later is `)`, else an operator.
fn inform6_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let out : Array[@lexer.Token] = []
  let mut queue : Array[@lexer.Token] = []
  let mut count = -1
  let mut previous_token : @token.TokenType? = None
  let significant = (t : @token.TokenType) => {
    !t.is_subtype_of(@token.comment) && !t.is_subtype_of(@token.text)
  }
  for tok in @lexer.run_regex(lx, inform6_lexer_def.force(), text, stack) {
    if previous_token is Some(p) &&
      p == @token.name_variable &&
      tok.value == "in" {
      queue = [tok]
      count = 2
    } else if count > 0 {
      if significant(tok.ttype) {
        count -= 1
      }
      queue.push(tok)
    } else {
      if count == 0 {
        if queue[queue.length() - 1].value == ")" {
          queue[0] = { ..queue[0], ttype: @token.keyword, }
        }
        out.append(queue)
        queue = []
        count = -1
      }
      out.push(tok)
    }
    if significant(tok.ttype) {
      previous_token = Some(tok.ttype)
    }
  }
  out.append(queue)
  out
}

///|
/// Python's pattern is the non-raw string `'\borigsource\b'`, i.e. with
/// backspace characters.
let inform6_origsource_re : @regex.Regex = @lexer.re(
  "\u{08}origsource\u{08}",
  flags=@regex.IGNORECASE,
)

///|
fn inform6_lexer_analyse(text : String) -> Double {
  if @lexer.search(inform6_origsource_re, text) {
    0.05
  } else {
    0.0
  }
}

///|
/// The token variant selected by the `i6t` option (`Inform7Lexer.__init__`).
fn inform7_variant(
  lx : @lexer.Lexer,
  variants : Array[(String, @lazy.Lazy[@lexer.RegexDef])],
) -> @lexer.RegexDef raise {
  let level = lx.options.get("i6t").unwrap_or("+i6t-not-inline")
  for v in variants {
    if v.0 == level {
      return v.1.force()
    }
  }
  fail("unknown i6t level \{level.escape()}")
}

///|
fn inform7_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, inform7_variant(lx, inform7_lexer_variants), text, stack)
}

///|
/// `Inform6TemplateLexer.get_tokens_unprocessed` starts in `+i6t-root`
/// unless a state is given.
fn inform6_template_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let stack = if stack == ["root"] { ["+i6t-root"] } else { stack }
  @lexer.run_regex(
    lx,
    inform7_variant(lx, inform6_template_lexer_variants),
    text,
    stack,
  )
}

///|
let tads3_pp : String = "^\{tads3_ws_pp}*#\{tads3_ws_pp}*"

///|
let tads3_if_false_re : @regex.Regex = @lexer.re(
  "\{tads3_pp}if\{tads3_ws_pp}+(0|nil)\{tads3_ws_pp}*$\\n?",
)

///|
let tads3_else_re : @regex.Regex = @lexer.re("\{tads3_pp}el(if|se)\\b")

///|
let tads3_if_re : @regex.Regex = @lexer.re("\{tads3_pp}if")

///|
let tads3_endif_re : @regex.Regex = @lexer.re("\{tads3_pp}endif\\b")

///|
/// `Tads3Lexer.get_tokens_unprocessed`: code in `#if 0` / `#if nil` blocks
/// is shown as comments.
fn tads3_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let mut if_false_level = 0
  @lexer.run_regex(lx, tads3_lexer_def.force(), text, stack).map(t => {
    if if_false_level == 0 {
      if t.ttype == @token.comment_preproc &&
        @lexer.matches(tads3_if_false_re, t.value) {
        if_false_level = 1
      }
      t
    } else if t.ttype == @token.comment_preproc {
      if if_false_level == 1 && @lexer.matches(tads3_else_re, t.value) {
        if_false_level = 0
      } else if @lexer.matches(tads3_if_re, t.value) {
        if_false_level += 1
      } else if @lexer.matches(tads3_endif_re, t.value) {
        if_false_level -= 1
      }
      t
    } else {
      { ..t, ttype: @token.comment, }
    }
  })
}

///|
fn tads3_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("__TADS") || text.contains("GameMainDef") {
    result += 0.2
  }
  if text.contains("versionInfo") && text.contains("IFID") {
    result += 0.1
  }
  result
}
