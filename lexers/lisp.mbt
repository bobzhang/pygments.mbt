// Hand-written parts of pygments/lexers/lisp.py.
// pydata: lisp_scheme_keywords = L.lisp.scheme_keywords
// pydata: lisp_scheme_builtins = L.lisp.scheme_builtins
// pydata: lisp_cl_builtin_function = set(L._cl_builtins.BUILTIN_FUNCTIONS)
// pydata: lisp_cl_special_forms = set(L._cl_builtins.SPECIAL_FORMS)
// pydata: lisp_cl_macros = set(L._cl_builtins.MACROS)
// pydata: lisp_cl_lambda_list_keywords = set(L._cl_builtins.LAMBDA_LIST_KEYWORDS)
// pydata: lisp_cl_declarations = set(L._cl_builtins.DECLARATIONS)
// pydata: lisp_cl_builtin_types = set(L._cl_builtins.BUILTIN_TYPES)
// pydata: lisp_cl_builtin_classes = set(L._cl_builtins.BUILTIN_CLASSES)
// pydata: lisp_el_builtin_function = set(L.lisp.EmacsLispLexer.builtin_function)
// pydata: lisp_el_special_forms = set(L.lisp.EmacsLispLexer.special_forms)
// pydata: lisp_el_error_keywords = set(L.lisp.EmacsLispLexer.error_keywords)
// pydata: lisp_el_builtin_function_highlighted = set(L.lisp.EmacsLispLexer.builtin_function_highlighted)
// pydata: lisp_el_macros = set(L.lisp.EmacsLispLexer.macros)
// pydata: lisp_el_lambda_list_keywords = set(L.lisp.EmacsLispLexer.lambda_list_keywords)
// pydata: lisp_shen_declarations = set(L.lisp.ShenLexer.DECLARATIONS)
// pydata: lisp_shen_special_forms = set(L.lisp.ShenLexer.SPECIAL_FORMS)
// pydata: lisp_shen_builtins = set(L.lisp.ShenLexer.BUILTINS)
// pydata: lisp_shen_builtins_anywhere = set(L.lisp.ShenLexer.BUILTINS_ANYWHERE)

///|
/// `SchemeLexer.get_tokens_unprocessed`: re-tags function and variable names
/// that are Scheme keywords or builtins.
fn scheme_retag(tokens : Array[@lexer.Token]) -> Array[@lexer.Token] {
  tokens.map(t => {
    if t.ttype != @token.name_function && t.ttype != @token.name_variable {
      t
    } else if lisp_scheme_keywords.contains(t.value) {
      { ..t, ttype: @token.keyword, }
    } else if lisp_scheme_builtins.contains(t.value) {
      { ..t, ttype: @token.name_builtin, }
    } else {
      t
    }
  })
}

///|
/// Callbacks of `SchemeLexer` (also used by subclasses such as LilyPond).
fn scheme_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "SchemeLexer.decimal_cb",
      (ctx, m, _) => {
        let v = m.matched()
        let t = if v.contains(".") {
          @token.number_float
        } else {
          @token.number_integer
        }
        ctx.emit(m.start(), t, v)
      },
    ),
  ])
}

///|
fn scheme_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  scheme_retag(
    @lexer.run_regex(
      lx,
      scheme_lexer_def.force(),
      text,
      stack,
      callbacks=scheme_lexer_callbacks(lx),
    ),
  )
}

///|
/// `CommonLispLexer.get_tokens_unprocessed`.
fn common_lisp_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, common_lisp_lexer_def.force(), text, ["root"]).map(t => {
    if t.ttype != @token.name_variable {
      return t
    }
    let v = t.value
    let ttype = if lisp_cl_builtin_function.contains(v) {
      @token.name_builtin
    } else if lisp_cl_special_forms.contains(v) {
      @token.keyword
    } else if lisp_cl_macros.contains(v) {
      @token.name_builtin
    } else if lisp_cl_lambda_list_keywords.contains(v) {
      @token.keyword
    } else if lisp_cl_declarations.contains(v) {
      @token.keyword
    } else if lisp_cl_builtin_types.contains(v) {
      @token.keyword_type
    } else if lisp_cl_builtin_classes.contains(v) {
      @token.name_class
    } else {
      return t
    }
    { ..t, ttype, }
  })
}

///|
let common_lisp_defun_re : @regex.Regex = @lexer.re("^\\s*\\(defun\\s")

///|
fn common_lisp_lexer_analyse(text : String) -> Double {
  if @lexer.search(common_lisp_defun_re, text) {
    0.8
  } else {
    0.0
  }
}

///|
fn hy_lexer_analyse(text : String) -> Double {
  if text.contains("(import ") || text.contains("(defn ") {
    0.9
  } else {
    0.0
  }
}

///|
/// `EmacsLispLexer.get_tokens_unprocessed`.
fn emacs_lisp_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(lx, emacs_lisp_lexer_def.force(), text, ["root"]).map(t => {
    if t.ttype != @token.name_variable {
      return t
    }
    let v = t.value
    let ttype = if lisp_el_builtin_function.contains(v) {
      @token.name_function
    } else if lisp_el_special_forms.contains(v) {
      @token.keyword
    } else if lisp_el_error_keywords.contains(v) {
      @token.name_exception
    } else if lisp_el_builtin_function_highlighted.contains(v) {
      @token.name_builtin
    } else if lisp_el_macros.contains(v) {
      @token.name_builtin
    } else if lisp_el_lambda_list_keywords.contains(v) {
      @token.keyword_pseudo
    } else {
      return t
    }
    { ..t, ttype, }
  })
}

///|
/// `ShenLexer._relevant`.
fn shen_relevant(t : @token.TokenType) -> Bool {
  t != @token.text &&
  t != @token.whitespace &&
  t != @token.comment_single &&
  t != @token.comment_multiline
}

///|
/// `ShenLexer.MAPPINGS.get(value, Name.Function)`.
fn shen_mapping(v : String) -> @token.TokenType {
  if lisp_shen_special_forms.contains(v) {
    @token.keyword
  } else if lisp_shen_builtins.contains(v) {
    @token.name_builtin
  } else if lisp_shen_declarations.contains(v) {
    @token.keyword
  } else {
    @token.name_function
  }
}

///|
/// Python's `str.istitle`.
fn py_istitle(s : String) -> Bool {
  let mut cased = false
  let mut prev_cased = false
  for c in s {
    if c.is_ascii_uppercase() || (c.to_int() > 127 && is_upper_char(c)) {
      if prev_cased {
        return false
      }
      prev_cased = true
      cased = true
    } else if c.is_ascii_lowercase() || (c.to_int() > 127 && is_lower_char(c)) {
      if !prev_cased {
        return false
      }
      prev_cased = true
      cased = true
    } else {
      prev_cased = false
    }
  }
  cased
}

///|
/// Approximation of Unicode uppercase for non-ASCII letters.
fn is_upper_char(c : Char) -> Bool {
  let s = c.to_string()
  s.to_lower() != s && s.to_upper() == s
}

///|
/// Approximation of Unicode lowercase for non-ASCII letters.
fn is_lower_char(c : Char) -> Bool {
  let s = c.to_string()
  s.to_upper() != s && s.to_lower() == s
}

///|
/// A consumable token stream (a Python generator shared by the Shen passes).
priv struct TokenCursor {
  toks : Array[@lexer.Token]
  mut i : Int
}

///|
fn TokenCursor::next(self : TokenCursor) -> @lexer.Token? {
  if self.i < self.toks.length() {
    let t = self.toks[self.i]
    self.i += 1
    Some(t)
  } else {
    None
  }
}

///|
/// `ShenLexer.get_tokens_unprocessed`.
fn shen_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  let raw = @lexer.run_regex(lx, shen_lexer_def.force(), text, stack)
  // _process_symbols
  let symbols = []
  let mut opening_paren = false
  for t in raw {
    let mut ttype = t.ttype
    if opening_paren &&
      (ttype == @token.literal || ttype == @token.name_variable) {
      ttype = shen_mapping(t.value)
    } else if ttype == @token.literal &&
      lisp_shen_builtins_anywhere.contains(t.value) {
      ttype = @token.name_builtin
    }
    opening_paren = t.value == "(" && ttype == @token.punctuation
    symbols.push({ ..t, ttype, })
  }
  // _process_declarations
  let out = []
  let cur = { toks: symbols, i: 0, }
  let mut opening_paren = false
  while cur.next() is Some(t) {
    out.push(t)
    if shen_relevant(t.ttype) {
      if opening_paren &&
        t.ttype == @token.keyword &&
        lisp_shen_declarations.contains(t.value) {
        shen_process_declaration(t.value, cur, out)
      }
      opening_paren = t.value == "(" && t.ttype == @token.punctuation
    }
  }
  out
}

///|
/// `ShenLexer._process_declaration`.
fn shen_process_declaration(
  declaration : String,
  cur : TokenCursor,
  out : Array[@lexer.Token],
) -> Unit raise {
  let mut last : @lexer.Token? = None
  while cur.next() is Some(t) {
    last = Some(t)
    if shen_relevant(t.ttype) {
      break
    }
    out.push(t)
  }
  // Python raises UnboundLocalError when the stream is exhausted.
  guard last is Some(tok) else { fail("UnboundLocalError: token") }
  let mut tok = tok
  let as_ = (t : @lexer.Token, ttype : @token.TokenType) => { ..t, ttype, }
  match declaration {
    "datatype" => {
      let mut prev_was_colon = false
      if tok.ttype == @token.literal {
        tok = as_(tok, @token.keyword_type)
      }
      out.push(tok)
      while cur.next() is Some(t) {
        let mut t = t
        if prev_was_colon && t.ttype == @token.literal {
          t = as_(t, @token.keyword_type)
        }
        out.push(t)
        if shen_relevant(t.ttype) {
          prev_was_colon = t.ttype == @token.literal && t.value == ":"
        }
      }
    }
    "package" => {
      if tok.ttype == @token.literal {
        tok = as_(tok, @token.name_namespace)
      }
      out.push(tok)
    }
    "define" => {
      if tok.ttype == @token.literal {
        tok = as_(tok, @token.name_function)
      }
      out.push(tok)
      while cur.next() is Some(t) {
        tok = t
        if shen_relevant(t.ttype) {
          break
        }
        out.push(t)
      }
      if tok.value == "{" && tok.ttype == @token.literal {
        out.push(as_(tok, @token.punctuation))
        // _process_signature
        while cur.next() is Some(t) {
          if t.ttype == @token.literal && t.value == "}" {
            out.push(as_(t, @token.punctuation))
            break
          } else if t.ttype == @token.literal || t.ttype == @token.name_function {
            out.push(
              as_(
                t,
                if py_istitle(t.value) {
                  @token.name_variable
                } else {
                  @token.keyword_type
                },
              ),
            )
          } else {
            out.push(t)
          }
        }
      } else {
        out.push(tok)
      }
    }
    _ => {
      if tok.ttype == @token.literal {
        tok = as_(tok, @token.name_function)
      }
      out.push(tok)
    }
  }
}
