// Hand-written parts of pygments/lexers/python.py.
// pydata: numpy_extra_keywords = L.python.NumPyLexer.EXTRA_KEYWORDS

///|
fn python_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "pythonw?(3(\\.\\d)?)?") ||
    pystr_prefix(text, 1000).contains("import ") {
    1.0
  } else {
    0.0
  }
}

///|
fn python2_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "pythonw?2(\\.\\d)?") {
    1.0
  } else {
    0.0
  }
}

///|
fn num_py_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, num_py_lexer_def.force(), text, stack).map(t => {
    if t.ttype == @token.name && numpy_extra_keywords.contains(t.value) {
      { ..t, ttype: @token.keyword_pseudo, }
    } else {
      t
    }
  })
}

///|
fn num_py_lexer_analyse(text : String) -> Double {
  let ltext = pystr_prefix(text, 1000)
  if (
      @lexer.shebang_matches(text, "pythonw?(3(\\.\\d)?)?") ||
      ltext.contains("import ")
    ) &&
    (ltext.contains("import numpy") || ltext.contains("from numpy import")) {
    1.0
  } else {
    0.0
  }
}
