// Hand-written parts of pygments/lexers/html.py.

///|
fn html_lexer_analyse(text : String) -> Double {
  if @lexer.html_doctype_matches(text) {
    0.5
  } else {
    0.0
  }
}

///|
/// `VueLexer` inherits `HtmlLexer.analyse_text`.
fn vue_lexer_analyse(text : String) -> Double {
  html_lexer_analyse(text)
}

///|
fn dtd_lexer_analyse(text : String) -> Double {
  if !@lexer.looks_like_xml(text) &&
    (
      text.contains("<!ELEMENT") ||
      text.contains("<!ATTLIST") ||
      text.contains("<!ENTITY")
    ) {
    0.8
  } else {
    0.0
  }
}

///|
fn xml_lexer_analyse(text : String) -> Double {
  if @lexer.looks_like_xml(text) {
    0.45 // less than HTML
  } else {
    0.0
  }
}

///|
fn xslt_lexer_analyse(text : String) -> Double {
  if @lexer.looks_like_xml(text) && text.contains("<xsl") {
    0.8
  } else {
    0.0
  }
}

///|
let xslt_extra_keywords : @set.Set[String] = @set.Set([
  "apply-imports", "apply-templates", "attribute", "attribute-set", "call-template",
  "choose", "comment", "copy", "copy-of", "decimal-format", "element", "fallback",
  "for-each", "if", "import", "include", "key", "message", "namespace-alias", "number",
  "otherwise", "output", "param", "preserve-space", "processing-instruction", "sort",
  "strip-space", "stylesheet", "template", "text", "transform", "value-of", "variable",
  "when", "with-param",
])

///|
let xslt_tag_re : @regex.Regex = @lexer.re("</?xsl:([^>]*)/?>?")

///|
/// `XsltLexer.get_tokens_unprocessed`: XSLT element tags become keywords.
fn xslt_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, xslt_lexer_def.force(), text, stack).map(t => {
    if t.ttype == @token.name_tag &&
      (xslt_tag_re.match_at(t.value, 0) catch { _ => None }) is Some(m) &&
      xslt_extra_keywords.contains(m.group(1).unwrap_or("")) {
      { ..t, ttype: @token.keyword, }
    } else {
      t
    }
  })
}

///|
fn haml_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  css_indentation_callbacks()
}

///|
fn scaml_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  css_indentation_callbacks()
}

///|
fn pug_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  css_indentation_callbacks()
}
