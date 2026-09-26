// Hand-written parts of pygments/lexers/templates.py (and
// `GosuTemplateLexer` of pygments/lexers/jvm.py).

///|
/// `SomeLexer.analyse_text(text)` as called from another lexer's
/// `analyse_text`: the `make_analysator` wrapper clamps to `[0, 1]`.
fn templates_score(info : @lexer.LexerInfo, text : String) -> Double {
  @lexer.clamp_score((info.analyse_text)(text))
}

///|
fn templates_has_erb_tags(text : String) -> Bool {
  text.contains("<%") && text.contains("%>")
}

// ---------------------------------------------------------------- ERB

///|
let erb_block_re : @regex.Regex = @lexer.re(
  "(<%%|%%>|<%=|<%#|<%-|<%|-%>|%>|^%[^%].*?$)",
  flags=@regex.MULTILINE,
)

///|
/// `ErbLexer.get_tokens_unprocessed`: splits the text at the ERB tags and
/// lexes the code between them with the `RubyLexer`.
fn erb_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let ruby = ruby_lexer(options=lx.options)
  let parts = erb_block_re.split(text).map(p => p.unwrap_or(""))
  let out : Array[@lexer.Token] = []
  let emit = (index, ttype, value) => out.push({ index, ttype, value, })
  let mut next = 0
  let mut state = 0
  let mut idx = 0
  // `tokens.pop()`; `None` stands for Python's `IndexError`
  let pop = () => {
    if next < parts.length() {
      next += 1
      Some(parts[next - 1])
    } else {
      None
    }
  }
  while true {
    if state == 0 {
      // text
      guard pop() is Some(val) else { break }
      emit(idx, @token.other, val)
      idx += val.length()
      state = 1
    } else if state == 1 {
      // block starts
      guard pop() is Some(tag) else { break }
      match tag {
        // literals
        "<%%" | "%%>" => {
          emit(idx, @token.other, tag)
          idx += 3
          state = 0
        }
        // comment
        "<%#" => {
          emit(idx, @token.comment_preproc, tag)
          guard pop() is Some(val) else { break }
          emit(idx + 3, @token.comment, val)
          idx += 3 + val.length()
          state = 2
        }
        // blocks or output
        "<%" | "<%=" | "<%-" => {
          emit(idx, @token.comment_preproc, tag)
          idx += tag.length()
          guard pop() is Some(data) else { break }
          for t in ruby.get_tokens_unprocessed(data) {
            emit(t.index + idx, t.ttype, t.value)
          }
          idx += data.length()
          state = 2
        }
        "%>" | "-%>" => {
          emit(idx, @token.error, tag)
          idx += tag.length()
          state = 0
        }
        // % raw ruby statements
        _ => {
          emit(idx, @token.comment_preproc, @lexer.py_slice(tag, 0, 1))
          let code = @lexer.py_slice(tag, 1, tag.length())
          for t in ruby.get_tokens_unprocessed(code) {
            emit(idx + 1 + t.index, t.ttype, t.value)
          }
          idx += tag.length()
          state = 0
        }
      }
    } else {
      // block ends
      guard pop() is Some(tag) else { break }
      if tag != "%>" && tag != "-%>" {
        emit(idx, @token.other, tag)
      } else {
        emit(idx, @token.comment_preproc, tag)
      }
      idx += tag.length()
      state = 0
    }
  }
  out
}

///|
fn erb_lexer_analyse(text : String) -> Double {
  if templates_has_erb_tags(text) {
    0.4
  } else {
    0.0
  }
}

///|
fn rhtml_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(erb_lexer_info, text) - 0.01
  if @lexer.html_doctype_matches(text) {
    // one more than the XmlErbLexer returns
    rv += 0.5
  }
  rv
}

///|
fn xml_erb_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(erb_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

///|
fn css_erb_lexer_analyse(text : String) -> Double {
  templates_score(erb_lexer_info, text) - 0.05
}

///|
fn javascript_erb_lexer_analyse(text : String) -> Double {
  templates_score(erb_lexer_info, text) - 0.05
}

// ---------------------------------------------------------------- Smarty

///|
let smarty_if_re : @regex.Regex = @lexer.re("\\{if\\s+.*?\\}.*?\\{/if\\}")

///|
let smarty_include_re : @regex.Regex = @lexer.re("\\{include\\s+file=.*?\\}")

///|
let smarty_foreach_re : @regex.Regex = @lexer.re(
  "\\{foreach\\s+.*?\\}.*?\\{/foreach\\}",
)

///|
let smarty_var_re : @regex.Regex = @lexer.re("\\{\\$.*?\\}")

///|
fn smarty_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(smarty_if_re, text) {
    rv += 0.15
  }
  if @lexer.search(smarty_include_re, text) {
    rv += 0.15
  }
  if @lexer.search(smarty_foreach_re, text) {
    rv += 0.15
  }
  if @lexer.search(smarty_var_re, text) {
    rv += 0.01
  }
  rv
}

///|
fn html_smarty_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(smarty_lexer_info, text) - 0.01
  if @lexer.html_doctype_matches(text) {
    rv += 0.5
  }
  rv
}

///|
fn xml_smarty_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(smarty_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

///|
fn css_smarty_lexer_analyse(text : String) -> Double {
  templates_score(smarty_lexer_info, text) - 0.05
}

///|
fn javascript_smarty_lexer_analyse(text : String) -> Double {
  templates_score(smarty_lexer_info, text) - 0.05
}

// ---------------------------------------------------------------- Velocity

///|
let velocity_macro_re : @regex.Regex = @lexer.re(
  "#\\{?macro\\}?\\(.*?\\).*?#\\{?end\\}?",
  flags=@regex.DOTALL,
)

///|
let velocity_if_re : @regex.Regex = @lexer.re(
  "#\\{?if\\}?\\(.+?\\).*?#\\{?end\\}?",
  flags=@regex.DOTALL,
)

///|
let velocity_foreach_re : @regex.Regex = @lexer.re(
  "#\\{?foreach\\}?\\(.+?\\).*?#\\{?end\\}?",
  flags=@regex.DOTALL,
)

///|
let velocity_var_re : @regex.Regex = @lexer.re(
  "\\$!?\\{?[a-zA-Z_]\\w*(\\([^)]*\\))?(\\.\\w+(\\([^)]*\\))?)*\\}?",
)

///|
fn velocity_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(velocity_macro_re, text) {
    rv += 0.25
  }
  if @lexer.search(velocity_if_re, text) {
    rv += 0.15
  }
  if @lexer.search(velocity_foreach_re, text) {
    rv += 0.15
  }
  if @lexer.search(velocity_var_re, text) {
    rv += 0.01
  }
  rv
}

///|
fn velocity_xml_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(velocity_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

// ---------------------------------------------------------------- Django

///|
let django_block_re : @regex.Regex = @lexer.re("\\{%\\s*(block|extends)")

///|
let django_if_re : @regex.Regex = @lexer.re("\\{%\\s*if\\s*.*?%\\}")

///|
let django_var_re : @regex.Regex = @lexer.re("\\{\\{.*?\\}\\}")

///|
fn django_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(django_block_re, text) {
    rv += 0.4
  }
  if @lexer.search(django_if_re, text) {
    rv += 0.1
  }
  if @lexer.search(django_var_re, text) {
    rv += 0.1
  }
  rv
}

///|
fn html_django_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(django_lexer_info, text) - 0.01
  if @lexer.html_doctype_matches(text) {
    rv += 0.5
  }
  rv
}

///|
fn xml_django_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(django_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

///|
fn css_django_lexer_analyse(text : String) -> Double {
  templates_score(django_lexer_info, text) - 0.05
}

///|
fn javascript_django_lexer_analyse(text : String) -> Double {
  templates_score(django_lexer_info, text) - 0.05
}

///|
let sql_jinja_ref_re : @regex.Regex = @lexer.re(
  "\\{\\{\\s*ref\\(.*\\)\\s*\\}\\}",
)

///|
let sql_jinja_source_re : @regex.Regex = @lexer.re(
  "\\{\\{\\s*source\\(.*\\)\\s*\\}\\}",
)

///|
let sql_jinja_macro_re : @regex.Regex = @lexer.re(
  "\\{%-?\\s*macro \\w+\\(.*\\)\\s*-?%\\}",
)

///|
fn sql_jinja_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  // dbt's ref function
  if @lexer.search(sql_jinja_ref_re, text) {
    rv += 0.4
  }
  // dbt's source function
  if @lexer.search(sql_jinja_source_re, text) {
    rv += 0.25
  }
  // Jinja macro
  if @lexer.search(sql_jinja_macro_re, text) {
    rv += 0.15
  }
  rv
}

// ---------------------------------------------------------------- Mason

///|
let mason_section_re : @regex.Regex = @lexer.re("</%(class|doc|init)>")

///|
let mason_component_re : @regex.Regex = @lexer.re("<&.+&>", flags=@regex.DOTALL)

///|
fn mason_lexer_analyse(text : String) -> Double {
  if @lexer.search(mason_section_re, text) {
    1.0
  } else if @lexer.search(mason_component_re, text) {
    0.11
  } else {
    0.0
  }
}

// ---------------------------------------------------------------- Cheetah

///|
/// `CheetahPythonLexer.get_tokens_unprocessed`: Python code in which the
/// `$` placeholders are `Comment.Preproc` instead of errors.
fn cheetah_python_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  python_lexer(options=lx.options)
  .get_tokens_unprocessed(text)
  .map(t => {
    if t.ttype == @token.error && t.value == "$" {
      { ..t, ttype: @token.comment_preproc, }
    } else {
      t
    }
  })
}

// ---------------------------------------------------------------- Genshi

///|
let genshi_interp_re : @regex.Regex = @lexer.re("\\$\\{.*?\\}")

///|
let genshi_attr_re : @regex.Regex = @lexer.re("py:(.*?)=[\"']")

///|
fn genshi_score(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(genshi_interp_re, text) {
    rv += 0.2
  }
  if @lexer.search(genshi_attr_re, text) {
    rv += 0.2
  }
  rv
}

///|
fn html_genshi_lexer_analyse(text : String) -> Double {
  genshi_score(text) + templates_score(html_lexer_info, text) - 0.01
}

///|
fn genshi_lexer_analyse(text : String) -> Double {
  genshi_score(text) + templates_score(xml_lexer_info, text) - 0.01
}

///|
fn javascript_genshi_lexer_analyse(text : String) -> Double {
  templates_score(genshi_lexer_info, text) - 0.05
}

///|
fn css_genshi_lexer_analyse(text : String) -> Double {
  templates_score(genshi_lexer_info, text) - 0.05
}

// ---------------------------------------------------------------- PHP

///|
fn html_php_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(php_lexer_info, text) - 0.01
  if @lexer.html_doctype_matches(text) {
    rv += 0.5
  }
  rv
}

///|
fn xml_php_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(php_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

///|
fn css_php_lexer_analyse(text : String) -> Double {
  templates_score(php_lexer_info, text) - 0.05
}

///|
fn javascript_php_lexer_analyse(text : String) -> Double {
  templates_score(php_lexer_info, text)
}

// ---------------------------------------------------------------- JSP, SSP, Tea

///|
fn jsp_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(java_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  if templates_has_erb_tags(text) {
    rv += 0.1
  }
  rv
}

///|
let ssp_val_re : @regex.Regex = @lexer.re("val \\w+\\s*:")

///|
fn ssp_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(ssp_val_re, text) {
    rv += 0.6
  }
  if @lexer.looks_like_xml(text) {
    rv += 0.2
  }
  if templates_has_erb_tags(text) {
    rv += 0.1
  }
  rv
}

///|
fn tea_template_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(tea_lang_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  if templates_has_erb_tags(text) {
    rv += 0.1
  }
  rv
}

// ---------------------------------------------------------------- Evoque

///|
/// Evoque templates use `$evoque`, which is unique.
fn evoque_lexer_analyse(text : String) -> Double {
  if text.contains("$evoque") {
    1.0
  } else {
    0.0
  }
}

///|
fn evoque_html_lexer_analyse(text : String) -> Double {
  templates_score(evoque_lexer_info, text)
}

///|
fn evoque_xml_lexer_analyse(text : String) -> Double {
  templates_score(evoque_lexer_info, text)
}

// ---------------------------------------------------------------- Lasso

///|
fn lasso_html_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(lasso_lexer_info, text) - 0.01
  if @lexer.html_doctype_matches(text) {
    // same as HTML lexer
    rv += 0.5
  }
  rv
}

///|
fn lasso_xml_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(lasso_lexer_info, text) - 0.01
  if @lexer.looks_like_xml(text) {
    rv += 0.4
  }
  rv
}

///|
let lasso_css_decl_re : @regex.Regex = @lexer.re("\\w+:[^;]+;")

///|
fn lasso_css_lexer_analyse(text : String) -> Double {
  let mut rv = templates_score(lasso_lexer_info, text) - 0.05
  if @lexer.search(lasso_css_decl_re, text) {
    rv += 0.1
  }
  if text.contains("padding:") {
    rv += 0.1
  }
  rv
}

///|
fn lasso_javascript_lexer_analyse(text : String) -> Double {
  templates_score(lasso_lexer_info, text) - 0.05
}

///|
/// `options['requiredelimiters'] = True` of the `LassoCssLexer` and
/// `LassoJavascriptLexer` constructors.
fn lasso_require_delimiters(options : @lexer.Options) -> @lexer.Options {
  let opts : @lexer.Options = Map([])
  for k, v in options {
    opts[k] = v
  }
  opts["requiredelimiters"] = "True"
  opts
}

///|
fn lasso_css_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let opts = lasso_require_delimiters(lx.options)
  @lexer.delegate(css_lexer(options=opts), lasso_lexer(options=opts), text)
}

///|
fn lasso_javascript_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let opts = lasso_require_delimiters(lx.options)
  @lexer.delegate(
    javascript_lexer(options=opts),
    lasso_lexer(options=opts),
    text,
  )
}
