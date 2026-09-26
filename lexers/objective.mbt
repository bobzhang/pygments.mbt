// Hand-written parts of pygments/lexers/objective.py.
// pydata: cocoa_interfaces_a = set(sorted(L._cocoa_builtins.COCOA_INTERFACES)[:1500])
// pydata: cocoa_interfaces_b = set(sorted(L._cocoa_builtins.COCOA_INTERFACES)[1500:])
// pydata: cocoa_protocols = L._cocoa_builtins.COCOA_PROTOCOLS
// pydata: cocoa_primitives = L._cocoa_builtins.COCOA_PRIMITIVES

///|
/// Re-tags `Name`/`Name.Class` tokens naming Cocoa builtins as
/// `Name.Builtin.Pseudo` (shared by the Objective-C variants and Swift).
/// `COCOA_INTERFACES` is exported in two halves to keep lines short.
fn cocoa_retag(tokens : Array[@lexer.Token]) -> Array[@lexer.Token] {
  tokens.map(t => {
    if t.ttype != @token.name && t.ttype != @token.name_class {
      return t
    }
    let v = t.value
    if cocoa_interfaces_a.contains(v) ||
      cocoa_interfaces_b.contains(v) ||
      cocoa_protocols.contains(v) ||
      cocoa_primitives.contains(v) {
      { ..t, ttype: @token.name_builtin_pseudo, }
    } else {
      t
    }
  })
}

///|
/// `GeneratedObjectiveCVariant.get_tokens_unprocessed`: the C/C++ base lexer
/// (with its type re-tagging) followed by the Cocoa re-tagging.
fn objective_run(
  lx : @lexer.Lexer,
  def : @lexer.RegexDef,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  cocoa_retag(c_family_retag(lx, @lexer.run_regex(lx, def, text, stack)))
}

///|
fn objective_c_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  objective_run(lx, objective_c_lexer_def.force(), text, stack)
}

///|
fn objective_cpp_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  objective_run(lx, objective_cpp_lexer_def.force(), text, stack)
}

///|
fn logos_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  objective_run(lx, logos_lexer_def.force(), text, stack)
}

///|
/// `SwiftLexer.get_tokens_unprocessed`.
fn swift_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  cocoa_retag(@lexer.run_regex(lx, swift_lexer_def.force(), text, stack))
}

///|
let oc_keywords_re : @regex.Regex = @lexer.re(
  "@(?:end|implementation|protocol)",
)

///|
let oc_message_re : @regex.Regex = @lexer.re(
  "\\[\\s*[a-zA-Z_]\\w*\\s+(?:[a-zA-Z_]\\w*\\s*\\]|(?:[a-zA-Z_]\\w*)?:)",
)

///|
let oc_number_literal_re : @regex.Regex = @lexer.re("@[0-9]+")

///|
/// `GeneratedObjectiveCVariant.analyse_text`.
fn objective_analyse(text : String) -> Double {
  if @lexer.search(oc_keywords_re, text) {
    1.0
  } else if text.contains("@\"") {
    0.8
  } else if @lexer.search(oc_number_literal_re, text) {
    0.7
  } else if @lexer.search(oc_message_re, text) {
    0.8
  } else {
    0.0
  }
}

///|
fn objective_c_lexer_analyse(text : String) -> Double {
  objective_analyse(text)
}

///|
fn objective_cpp_lexer_analyse(text : String) -> Double {
  objective_analyse(text)
}

///|
let logos_keywords_re : @regex.Regex = @lexer.re("%(?:hook|ctor|init|c\\()")

///|
fn logos_lexer_analyse(text : String) -> Double {
  if @lexer.search(logos_keywords_re, text) {
    1.0
  } else {
    0.0
  }
}
