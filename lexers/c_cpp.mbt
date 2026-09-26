// Hand-written parts of pygments/lexers/c_cpp.py.
// pydata: c_stdlib_types = L.c_cpp.CFamilyLexer.stdlib_types
// pydata: c_c99_types = L.c_cpp.CFamilyLexer.c99_types
// pydata: c_linux_types = L.c_cpp.CFamilyLexer.linux_types
// pydata: c_c11_atomic_types = L.c_cpp.CFamilyLexer.c11_atomic_types

///|
/// `CFamilyLexer.get_tokens_unprocessed`: re-tags `Name` tokens that are
/// well-known type names as `Keyword.Type`, controlled by the
/// `stdlibhighlighting`, `c99highlighting`, `c11highlighting` and
/// `platformhighlighting` options.
fn c_family_retag(
  lx : @lexer.Lexer,
  tokens : Array[@lexer.Token],
) -> Array[@lexer.Token] raise {
  let stdlib = @lexer.get_bool_opt(lx.options, "stdlibhighlighting", true)
  let c99 = @lexer.get_bool_opt(lx.options, "c99highlighting", true)
  let c11 = @lexer.get_bool_opt(lx.options, "c11highlighting", true)
  let platform = @lexer.get_bool_opt(lx.options, "platformhighlighting", true)
  tokens.map(t => {
    if t.ttype != @token.name {
      return t
    }
    let v = t.value
    if (stdlib && c_stdlib_types.contains(v)) ||
      (c99 && c_c99_types.contains(v)) ||
      (c11 && c_c11_atomic_types.contains(v)) ||
      (platform && c_linux_types.contains(v)) {
      { ..t, ttype: @token.keyword_type, }
    } else {
      t
    }
  })
}

///|
fn c_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_retag(lx, @lexer.run_regex(lx, c_lexer_def.force(), text, stack))
}

///|
fn cpp_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  c_family_retag(lx, @lexer.run_regex(lx, cpp_lexer_def.force(), text, stack))
}

///|
let c_include_re : @regex.Regex = @lexer.re(
  "^\\s*#include [<\"]",
  flags=@regex.MULTILINE,
)

///|
let c_ifdef_re : @regex.Regex = @lexer.re(
  "^\\s*#ifn?def ",
  flags=@regex.MULTILINE,
)

///|
fn c_lexer_analyse(text : String) -> Double {
  if @lexer.search(c_include_re, text) || @lexer.search(c_ifdef_re, text) {
    0.1
  } else {
    0.0
  }
}

///|
let cpp_include_re : @regex.Regex = @lexer.re("#include <[a-z_]+>")

///|
let cpp_using_re : @regex.Regex = @lexer.re("using namespace ")

///|
fn cpp_lexer_analyse(text : String) -> Double {
  if @lexer.search(cpp_include_re, text) {
    0.2
  } else if @lexer.search(cpp_using_re, text) {
    0.4
  } else {
    0.0
  }
}
