// Hand-written parts of pygments/lexers/parsers.py.

///|
/// The Ragel lexers return `'@LANG: <lang>' in text` (a `bool`).
fn ragel_lang_analyse(text : String, lang : String) -> Double {
  if text.contains("@LANG: " + lang) {
    1.0
  } else {
    0.0
  }
}

///|
fn ragel_embedded_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "indep")
}

///|
fn ragel_ruby_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "ruby")
}

///|
fn ragel_c_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "c")
}

///|
fn ragel_d_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "d")
}

///|
fn ragel_cpp_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "c++")
}

///|
fn ragel_objective_c_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "objc")
}

///|
fn ragel_java_lexer_analyse(text : String) -> Double {
  ragel_lang_analyse(text, "java")
}

///|
/// `AntlrLexer.analyse_text` returns `re.search(...)`, i.e. an `re.Match`
/// object or `None`. `make_analysator` cannot convert a match object to
/// `float`, so the score is always 0.
fn antlr_lexer_analyse(_text : String) -> Double {
  0.0
}

///|
/// The ANTLR target lexers return `AntlrLexer.analyse_text(text) and
/// re.search(...)`. The first operand is always `0.0` (see
/// `antlr_lexer_analyse`); even when it is not, the result would be a match
/// object, which scores 0 as well.
fn antlr_target_analyse(text : String) -> Double {
  let _ = @lexer.clamp_score(antlr_lexer_analyse(text))
  0.0
}

///|
fn antlr_cpp_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
fn antlr_objective_c_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
fn antlr_c_sharp_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
fn antlr_python_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
/// `AntlrLexer.analyse_text(text) and 0.9`.
fn antlr_java_lexer_analyse(text : String) -> Double {
  let base = @lexer.clamp_score(antlr_lexer_analyse(text))
  if base == 0.0 {
    base
  } else {
    0.9
  }
}

///|
fn antlr_ruby_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
fn antlr_perl_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}

///|
fn antlr_action_script_lexer_analyse(text : String) -> Double {
  antlr_target_analyse(text)
}
