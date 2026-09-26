// Hand-written parts of pygments/lexers/c_like.py.
// pydata: cuda_function_qualifiers = L.c_like.CudaLexer.function_qualifiers
// pydata: cuda_variable_qualifiers = L.c_like.CudaLexer.variable_qualifiers
// pydata: cuda_vector_types = L.c_like.CudaLexer.vector_types
// pydata: cuda_variables = L.c_like.CudaLexer.variables
// pydata: cuda_functions = L.c_like.CudaLexer.functions
// pydata: cuda_execution_confs = L.c_like.CudaLexer.execution_confs
// pydata: swig_directives = L.c_like.SwigLexer.swig_directives
// pydata: arduino_structure = L.c_like.ArduinoLexer.structure
// pydata: arduino_operators = L.c_like.ArduinoLexer.operators
// pydata: arduino_variables = L.c_like.ArduinoLexer.variables
// pydata: arduino_suppress_highlight = L.c_like.ArduinoLexer.suppress_highlight
// pydata: arduino_functions = L.c_like.ArduinoLexer.functions

///|
/// `CFamilyLexer.get_tokens_unprocessed` on the tables `def` of a subclass.
fn c_family_run(
  lx : @lexer.Lexer,
  def : @lexer.RegexDef,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_retag(lx, @lexer.run_regex(lx, def, text, stack))
}

///|
fn pike_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, pike_lexer_def.force(), text, stack)
}

///|
fn nes_c_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, nes_c_lexer_def.force(), text, stack)
}

///|
fn ec_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, ec_lexer_def.force(), text, stack)
}

///|
fn swig_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, swig_lexer_def.force(), text, stack)
}

///|
fn mql_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, mql_lexer_def.force(), text, stack)
}

///|
fn charmci_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, charmci_lexer_def.force(), text, stack)
}

///|
fn omg_idl_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, omg_idl_lexer_def.force(), text, stack)
}

///|
fn promela_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, promela_lexer_def.force(), text, stack)
}

///|
/// `CudaLexer.get_tokens_unprocessed`.
fn cuda_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, cuda_lexer_def.force(), text, stack).map(t => {
    if t.ttype != @token.name {
      return t
    }
    let v = t.value
    let ttype = if cuda_variable_qualifiers.contains(v) {
      @token.keyword_type
    } else if cuda_vector_types.contains(v) {
      @token.keyword_type
    } else if cuda_variables.contains(v) {
      @token.name_builtin
    } else if cuda_execution_confs.contains(v) {
      @token.keyword_pseudo
    } else if cuda_function_qualifiers.contains(v) {
      @token.keyword_reserved
    } else if cuda_functions.contains(v) {
      @token.name_function
    } else {
      t.ttype
    }
    { ..t, ttype, }
  })
}

///|
/// `ArduinoLexer.get_tokens_unprocessed`: re-tags by value, whatever the
/// token type.
fn arduino_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_run(lx, arduino_lexer_def.force(), text, stack).map(t => {
    let v = t.value
    let ttype = if arduino_structure.contains(v) {
      @token.name_builtin
    } else if arduino_operators.contains(v) {
      @token.operator
    } else if arduino_variables.contains(v) {
      @token.keyword_reserved
    } else if arduino_suppress_highlight.contains(v) {
      @token.name
    } else if arduino_functions.contains(v) {
      @token.name_function
    } else {
      t.ttype
    }
    { ..t, ttype, }
  })
}

///|
fn pike_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}

///|
fn nes_c_lexer_analyse(text : String) -> Double {
  c_lexer_analyse(text)
}

///|
fn ec_lexer_analyse(text : String) -> Double {
  c_lexer_analyse(text)
}

///|
fn cuda_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}

///|
fn mql_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}

///|
fn arduino_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}

///|
fn charmci_lexer_analyse(text : String) -> Double {
  cpp_lexer_analyse(text)
}

///|
fn omg_idl_lexer_analyse(text : String) -> Double {
  c_lexer_analyse(text)
}

///|
fn promela_lexer_analyse(text : String) -> Double {
  c_lexer_analyse(text)
}

///|
let swig_directive_re : @regex.Regex = @lexer.re(
  "^\\s*(%[a-z_][a-z0-9_]*)",
  flags=@regex.MULTILINE,
)

///|
/// `SwigLexer.analyse_text`: SWIG directives at the start of a line.
fn swig_lexer_analyse(text : String) -> Double {
  let found = swig_directive_re.find_all(text) catch { _ => return 0.0 }
  let mut rv = 0.0
  for m in found {
    if swig_directives.contains(m.group(1).unwrap_or("")) {
      rv = 0.98
      break
    } else {
      rv = 0.91
    }
  }
  rv
}
