// Hand-written parts of pygments/lexers/modula2.py.
// The per-dialect sets computed by `Modula2Lexer.set_dialect`:
// pydata: m2_dialects = L.modula2.Modula2Lexer.dialects
// pydata: m2_lexemes_to_reject = {d: sorted((lambda l: (l.set_dialect(d), l.lexemes_to_reject)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_reserved_words = {d: sorted((lambda l: (l.set_dialect(d), l.reserved_words)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_builtins = {d: sorted((lambda l: (l.set_dialect(d), l.builtins)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_pseudo_builtins = {d: sorted((lambda l: (l.set_dialect(d), l.pseudo_builtins)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_adts = {d: sorted((lambda l: (l.set_dialect(d), l.adts)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_modules = {d: sorted((lambda l: (l.set_dialect(d), l.modules)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_types = {d: sorted((lambda l: (l.set_dialect(d), l.types)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_procedures = {d: sorted((lambda l: (l.set_dialect(d), l.procedures)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_variables = {d: sorted((lambda l: (l.set_dialect(d), l.variables)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}
// pydata: m2_constants = {d: sorted((lambda l: (l.set_dialect(d), l.constants)[1])(L.modula2.Modula2Lexer())) for d in L.modula2.Modula2Lexer.dialects}

///|
/// The identifier sets of one dialect (the attributes `set_dialect` updates).
priv struct M2Dialect {
  name : String
  lexemes_to_reject : @set.Set[String]
  reserved_words : @set.Set[String]
  builtins : @set.Set[String]
  pseudo_builtins : @set.Set[String]
  adts : @set.Set[String]
  modules : @set.Set[String]
  types : @set.Set[String]
  procedures : @set.Set[String]
  variables : @set.Set[String]
  constants : @set.Set[String]
}

///|
/// `Modula2Lexer.set_dialect`: unknown names fall back to `unknown`.
fn m2_dialect(dialect_id : String) -> M2Dialect {
  let name = if m2_dialects.contains(dialect_id) {
    dialect_id
  } else {
    "unknown"
  }
  let get = (db : Map[String, Array[String]]) => {
    @set.Set(db.get(name).unwrap_or([]))
  }
  {
    name,
    lexemes_to_reject: get(m2_lexemes_to_reject),
    reserved_words: get(m2_reserved_words),
    builtins: get(m2_builtins),
    pseudo_builtins: get(m2_pseudo_builtins),
    adts: get(m2_adts),
    modules: get(m2_modules),
    types: get(m2_types),
    procedures: get(m2_procedures),
    variables: get(m2_variables),
    constants: get(m2_constants),
  }
}

///|
/// `Modula2Lexer.get_dialect_from_dialect_tag`: the dialect named by a
/// `(*!dialect*)` comment, or `unknown`.
fn m2_dialect_from_tag(tag : String) -> String {
  if tag.length() > 5 && tag.has_prefix("(*!") && tag.has_suffix("*)") {
    let indicator = @lexer.py_slice(tag, 3, tag.length() - 2)
    for i in 1..<m2_dialects.length() {
      if indicator == m2_dialects[i] {
        return indicator
      }
    }
  }
  "unknown"
}

///|
/// `Modula2Lexer.__init__` and `get_tokens_unprocessed`: dialect-dependent
/// re-tagging of identifiers, numbers, comments and rejected lexemes, and the
/// Algol publication style.
fn modula2_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  // __init__
  let mut dialect = m2_dialect("unknown")
  let valid = m2_dialects[1:m2_dialects.length() - 1]
  for option in @lexer.get_list_opt(lx.options, "dialect", []) {
    if valid.contains(option) {
      dialect = m2_dialect(option)
      break
    }
  }
  let mut dialect_set_by_tag = false
  let styles = @lexer.get_list_opt(lx.options, "style", [])
  let algol_publication_mode = styles.contains("algol") ||
    styles.contains("algol_nu")
  let treat_stdlib_adts_as_builtins = @lexer.get_bool_opt(
    lx.options,
    "treat_stdlib_adts_as_builtins",
    true,
  )
  // get_tokens_unprocessed
  let out = []
  for t in @lexer.run_regex(lx, modula2_lexer_def.force(), text, stack) {
    let mut token = t.ttype
    let mut value = t.value
    // check for dialect tag if dialect has not been set by tag
    if !dialect_set_by_tag && token == @token.comment_special {
      let indicated = m2_dialect_from_tag(value)
      if indicated != "unknown" {
        dialect = m2_dialect(indicated)
        dialect_set_by_tag = true
      }
    }
    let d = dialect
    let lower = (v : String) => {
      if algol_publication_mode {
        v.to_lower()
      } else {
        v
      }
    }
    if token == @token.name {
      // reserved words, predefined and stdlib identifiers
      if d.reserved_words.contains(value) {
        token = @token.keyword_reserved
        value = lower(value)
      } else if d.builtins.contains(value) {
        token = @token.name_builtin
        value = lower(value)
      } else if d.pseudo_builtins.contains(value) {
        token = @token.name_builtin_pseudo
        value = lower(value)
      } else if d.adts.contains(value) {
        if !treat_stdlib_adts_as_builtins {
          token = @token.name_namespace
        } else {
          token = @token.name_builtin_pseudo
          value = lower(value)
        }
      } else if d.modules.contains(value) {
        token = @token.name_namespace
      } else if d.types.contains(value) {
        token = @token.name_class
      } else if d.procedures.contains(value) {
        token = @token.name_function
      } else if d.variables.contains(value) {
        token = @token.name_variable
      } else if d.constants.contains(value) {
        token = @token.name_constant
      }
    } else if token.is_subtype_of(@token.number) {
      if !["unknown", "m2r10", "objm2"].contains(d.name) {
        // prefix number literals are errors for PIM and ISO dialects
        let prefix = @lexer.py_slice(value, 0, 2)
        if value.contains("'") ||
          prefix == "0b" ||
          prefix == "0x" ||
          prefix == "0u" {
          token = @token.error
        }
      } else if d.name == "m2r10" || d.name == "objm2" {
        // base-8 literals, suffix base-16 literals and reals with E are
        // errors for M2 R10 and ObjM2
        if token == @token.number_oct {
          token = @token.error
        } else if token == @token.number_hex && value.contains("H") {
          token = @token.error
        } else if token == @token.number_float && value.contains("E") {
          token = @token.error
        }
      }
    } else if token.is_subtype_of(@token.comment) {
      // single line comments are errors for PIM and ISO dialects
      if token == @token.comment_single &&
        !["unknown", "m2r10", "objm2"].contains(d.name) {
        token = @token.error
      }
      if token == @token.comment_preproc {
        if value.has_prefix("<*") && d.name.has_prefix("m2pim") {
          // ISO pragmas are errors for PIM dialects
          token = @token.error
        } else if value.has_prefix("(*$") &&
          d.name != "unknown" &&
          !d.name.has_prefix("m2pim") {
          // PIM pragmas are comments for other dialects
          token = @token.comment_multiline
        }
      }
    } else {
      // lexemes in the dialect's reject set are errors
      if d.lexemes_to_reject.contains(value) {
        token = @token.error
      }
      // substitute lexemes in Algol mode
      if algol_publication_mode {
        value = match value {
          "#" => "≠"
          "<=" => "≤"
          ">=" => "≥"
          "==" => "≡"
          "*." => "•"
          v => v
        }
      }
    }
    out.push(({ index: t.index, ttype: token, value, } : @lexer.Token))
  }
  out
}

///|
let m2_procedure_re : @regex.Regex = @lexer.re("\\bPROCEDURE\\b")

///|
let m2_function_re : @regex.Regex = @lexer.re("\\bFUNCTION\\b")

///|
/// `Modula2Lexer.analyse_text`: Pascal-like, but uses `PROCEDURE` rather
/// than `FUNCTION`.
fn modula2_lexer_analyse(text : String) -> Double {
  if !(text.contains("(*") && text.contains("*)") && text.contains(":=")) {
    return 0.0
  }
  let mut result = 0.0
  if @lexer.search(m2_procedure_re, text) {
    result += 0.6
  }
  if @lexer.search(m2_function_re, text) {
    result = 0.0
  }
  result
}
