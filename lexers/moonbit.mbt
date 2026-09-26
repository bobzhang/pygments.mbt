// A MoonBit lexer. Upstream Pygments has none; this one exists only in the
// MoonBit port and is registered through the line below.
// extra-lexer: MoonBitLexer moon_bit_lexer

///|
pub let moon_bit_lexer_info : @lexer.LexerInfo = {
  class_name: "MoonBitLexer",
  name: "MoonBit",
  aliases: ["moonbit", "mbt"],
  filenames: ["*.mbt", "*.mbti", "*.mbtx"],
  alias_filenames: [],
  mimetypes: ["text/x-moonbit"],
  priority: 0.0,
  url: "https://www.moonbitlang.com",
  version_added: "",
  analyse_text: @lexer.no_analyse,
  doc: "\n    For MoonBit source code (`.mbt`, `.mbti`, `.mbtx`).\n\n    Not part of upstream Pygments; provided by the MoonBit port.\n    ",
}

///|
/// `\b(w1|w2|...)\b`
fn mbt_words(ws : Array[String]) -> String {
  "\\b(" + ws.join("|") + ")\\b"
}

///|
fn mbt_rule(
  pattern : String,
  action : @lexer.Action,
  transition? : Array[@lexer.StateOp],
) -> @lexer.Rule {
  @lexer.Rule::new(pattern, @regex.MULTILINE, action, transition)
}

///|
let mbt_keywords : Array[String] = [
  "as", "async", "break", "catch", "const", "continue", "declare", "defer", "derive",
  "else", "errdefer", "extend", "extern", "for", "guard", "if", "impl", "import",
  "in", "is", "lexmatch", "lexscan", "let", "letrec", "loop", "match", "mut", "nobreak",
  "noraise", "priv", "pub", "raise", "return", "self", "test", "try", "using", "where",
  "while", "with",
]

///|
let mbt_type_decls : Array[String] = [
  "enum", "enumview", "struct", "suberror", "trait", "traitalias", "type", "typealias",
]

///|
let mbt_builtin_types : Array[String] = [
  "Array", "ArrayView", "BigInt", "Bool", "Byte", "Bytes", "BytesView", "Char", "Double",
  "Error", "FixedArray", "Float", "Int", "Int16", "Int64", "Iter", "Json", "Map",
  "Option", "ReadOnlyArray", "Ref", "Result", "Self", "Set", "String", "StringBuilder",
  "StringView", "UInt", "UInt16", "UInt64", "Unit",
]

///|
let mbt_builtin_functions : Array[String] = [
  "abort", "assert_eq", "assert_false", "assert_not_eq", "assert_true", "debug_inspect",
  "fail", "ignore", "inspect", "json_inspect", "panic", "physical_equal", "println",
  "print", "repr",
]

///|
let moon_bit_lexer_def : @lazy.Lazy[@lexer.RegexDef] = @lazy.Lazy(() => {
  let rules : Array[@lexer.Rule] = []
  let states : Array[(String, Array[Int])] = []
  fn state(name : String, rs : Array[@lexer.Rule]) {
    let idx = []
    for r in rs {
      idx.push(rules.length())
      rules.push(r)
    }
    states.push((name, idx))
  }

  let ws = @lexer.Emit(tk_text_whitespace)
  let code = [
    mbt_rule("\\n", ws),
    mbt_rule("[ \\t\\r\\f\\v]+", ws),
    // `///|` block separators, doc comments and comments
    mbt_rule("///\\|[^\\n]*", Emit(tk_comment_special)),
    mbt_rule("///[^\\n]*", Emit(tk_literal_string_doc)),
    mbt_rule("//[^\\n]*", Emit(tk_comment_single)),
    // multi-line strings: `#|` raw, `$|` interpolated
    mbt_rule("#\\|[^\\n]*", Emit(tk_literal_string)),
    mbt_rule("\\$\\|", Emit(tk_literal_string), transition=[Push("mstring")]),
    // attributes
    mbt_rule("#[a-z_][\\w.]*", Emit(tk_name_decorator)),
    // literals
    mbt_rule("re\"", Emit(tk_literal_string_regex), transition=[Push("regex")]),
    mbt_rule("b\"", Emit(tk_literal_string), transition=[Push("bytes")]),
    mbt_rule(
      "b?'(\\\\(u\\{[0-9a-fA-F]+\\}|x[0-9a-fA-F]{2}|o[0-7]{3}|u[0-9a-fA-F]{4}|.)|[^\\\\'\\n])'",
      Emit(tk_literal_string_char),
    ),
    mbt_rule("\"", Emit(tk_literal_string_double), transition=[Push("string")]),
    mbt_rule(
      "0[xX][0-9a-fA-F][0-9a-fA-F_]*(\\.[0-9a-fA-F_]*([pP][+-]?[0-9]+)?|[pP][+-]?[0-9]+)F?\\b",
      Emit(tk_literal_number_float),
    ),
    mbt_rule(
      "0[xX][0-9a-fA-F][0-9a-fA-F_]*(UL|L|U|N)?\\b",
      Emit(tk_literal_number_hex),
    ),
    mbt_rule("0[oO][0-7][0-7_]*(UL|L|U|N)?\\b", Emit(tk_literal_number_oct)),
    mbt_rule("0[bB][01][01_]*(UL|L|U|N)?\\b", Emit(tk_literal_number_bin)),
    mbt_rule(
      "[0-9][0-9_]*(\\.[0-9][0-9_]*([eE][+-]?[0-9]+)?|[eE][+-]?[0-9]+)F?\\b",
      Emit(tk_literal_number_float),
    ),
    mbt_rule("[0-9][0-9_]*(UL|L|U|N|F)?\\b", Emit(tk_literal_number_integer)),
    // declarations
    mbt_rule("(fn)\\b", Emit(tk_keyword_declaration), transition=[
      Push("funcname"),
    ]),
    mbt_rule(
      mbt_words(mbt_type_decls) + "(\\s+)([A-Z]\\w*)",
      ByGroups([
        Emit(tk_keyword_declaration),
        Emit(tk_text_whitespace),
        Emit(tk_name_class),
      ]),
    ),
    mbt_rule(mbt_words(mbt_type_decls), Emit(tk_keyword_declaration)),
    mbt_rule("(true|false)\\b", Emit(tk_keyword_constant)),
    mbt_rule(mbt_words(mbt_keywords), Emit(tk_keyword)),
    mbt_rule(mbt_words(mbt_builtin_types), Emit(tk_keyword_type)),
    mbt_rule("(Some|None|Ok|Err)\\b", Emit(tk_name_builtin)),
    mbt_rule(mbt_words(mbt_builtin_functions), Emit(tk_name_builtin)),
    // package references `@pkg`, `@pkg/sub.fn`
    mbt_rule("@[a-z_][\\w/]*", Emit(tk_name_namespace)),
    mbt_rule("[A-Z]\\w*", Emit(tk_name_class)),
    mbt_rule("_\\b", Emit(tk_keyword_pseudo)),
    mbt_rule("[a-z_]\\w*", Emit(tk_name)),
    mbt_rule(
      "=>|->|\\|>|::|\\.\\.[=<]|\\.\\.|<\\+|<\\?|[-+*/%=<>!&|^~?]+",
      Emit(tk_operator),
    ),
    mbt_rule("[(){}\\[\\],;:.]", Emit(tk_punctuation)),
  ]
  state("root", code)
  state("funcname", [
    mbt_rule("[ \\t]+", ws),
    mbt_rule("\\[", Emit(tk_punctuation), transition=[Push("generics")]),
    mbt_rule(
      "([A-Z]\\w*)(::)",
      ByGroups([Emit(tk_name_class), Emit(tk_punctuation)]),
    ),
    mbt_rule("[a-z_]\\w*", Emit(tk_name_function), transition=[Pop]),
    mbt_rule("", Nop, transition=[Pop]),
  ])
  state(
    "generics",
    [mbt_rule("\\]", Emit(tk_punctuation), transition=[Pop])] + code,
  )
  let escape = mbt_rule(
    "\\\\(u\\{[0-9a-fA-F]+\\}|x[0-9a-fA-F]{2}|o[0-7]{3}|u[0-9a-fA-F]{4}|.)",
    Emit(tk_literal_string_escape),
  )
  let interp = mbt_rule("\\\\\\{", Emit(tk_literal_string_interpol), transition=[
    Push("interp"),
  ])
  state("string", [
    mbt_rule("\"", Emit(tk_literal_string_double), transition=[Pop]),
    interp,
    escape,
    mbt_rule("[^\"\\\\\\n]+", Emit(tk_literal_string_double)),
    mbt_rule("\\n", ws, transition=[Pop]),
  ])
  state("bytes", [
    mbt_rule("\"", Emit(tk_literal_string), transition=[Pop]),
    escape,
    mbt_rule("[^\"\\\\\\n]+", Emit(tk_literal_string)),
    mbt_rule("\\n", ws, transition=[Pop]),
  ])
  state("regex", [
    mbt_rule("\"", Emit(tk_literal_string_regex), transition=[Pop]),
    mbt_rule("\\\\.", Emit(tk_literal_string_escape)),
    mbt_rule("[^\"\\\\\\n]+", Emit(tk_literal_string_regex)),
    mbt_rule("\\n", ws, transition=[Pop]),
  ])
  state("mstring", [
    interp,
    mbt_rule("\\\\[^{]", Emit(tk_literal_string)),
    mbt_rule("[^\\\\\\n]+", Emit(tk_literal_string)),
    mbt_rule("\\n", ws, transition=[Pop]),
  ])
  state(
    "interp",
    [
      mbt_rule("\\}", Emit(tk_literal_string_interpol), transition=[Pop]),
      mbt_rule("\\{", Emit(tk_punctuation), transition=[Push("curly")]),
    ] +
    code,
  )
  state(
    "curly",
    [
      mbt_rule("\\}", Emit(tk_punctuation), transition=[Pop]),
      mbt_rule("\\{", Emit(tk_punctuation), transition=[Dup]),
    ] +
    code,
  )
  @lexer.RegexDef::new(
    "MoonBitLexer",
    states.map(s => s.0),
    rules,
    states.map(s => s.1),
  )
})

///|
/// Creates a `MoonBitLexer` (MoonBit).
pub fn moon_bit_lexer(
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  @lexer.Lexer::new(
    moon_bit_lexer_info,
    options,
    opts => moon_bit_lexer(options=opts),
    (lx, text, stack) => {
      @lexer.run_regex(lx, moon_bit_lexer_def.force(), text, stack)
    },
  )
}
