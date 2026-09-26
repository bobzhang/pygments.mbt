// Hand-written parts of pygments/lexers/jvm.py.
// pydata: aspectj_keywords = L.jvm.AspectJLexer.aj_keywords
// pydata: aspectj_inter_type = L.jvm.AspectJLexer.aj_inter_type
// pydata: aspectj_inter_type_annotation = L.jvm.AspectJLexer.aj_inter_type_annotation

///|
/// `AspectJLexer.get_tokens_unprocessed`.
fn aspect_j_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let out = []
  for t in @lexer.run_regex(lx, aspect_j_lexer_def.force(), text, stack) {
    if t.ttype == @token.name && aspectj_keywords.contains(t.value) {
      out.push({ ..t, ttype: @token.keyword, })
    } else if t.ttype == @token.name_label &&
      aspectj_inter_type.contains(t.value) {
      let n = t.value.length()
      out.push({
        index: t.index,
        ttype: @token.keyword,
        value: @lexer.py_slice(t.value, 0, n - 1),
      })
      out.push({
        index: t.index,
        ttype: @token.operator,
        value: @lexer.py_slice(t.value, n - 1, n),
      })
    } else if t.ttype == @token.name_decorator &&
      aspectj_inter_type_annotation.contains(t.value) {
      out.push({ ..t, ttype: @token.keyword, })
    } else {
      out.push(t)
    }
  }
  out
}

///|
/// `GosuTemplateLexer.get_tokens_unprocessed`: a default `GosuLexer`
/// started in the `templateText` state.
fn gosu_template_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  gosu_lexer().get_tokens_unprocessed(text, stack=["templateText"])
}

///|
fn groovy_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "groovy") {
    1.0
  } else {
    0.0
  }
}

///|
let jasmin_class_re : @regex.Regex = @lexer.re(
  "^\\s*\\.class\\s",
  flags=@regex.MULTILINE,
)

///|
let jasmin_insn_re : @regex.Regex = @lexer.re(
  "^\\s*[a-z]+_[a-z]+\\b",
  flags=@regex.MULTILINE,
)

///|
let jasmin_directive_re : @regex.Regex = @lexer.re(
  "^\\s*\\.(attribute|bytecode|debug|deprecated|enclosing|inner|interface|limit|set|signature|stack)\\b",
  flags=@regex.MULTILINE,
)

///|
fn jasmin_lexer_analyse(text : String) -> Double {
  let mut score = 0.0
  if @lexer.search(jasmin_class_re, text) {
    score += 0.5
    if @lexer.search(jasmin_insn_re, text) {
      score += 0.3
    }
  }
  if @lexer.search(jasmin_directive_re, text) {
    score += 0.6
  }
  if score > 1.0 {
    1.0
  } else {
    score
  }
}
