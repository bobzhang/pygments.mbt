// Hand-written parts of pygments/lexers/actionscript.py.

///|
/// Only used to disambiguate between ActionScript and ActionScript 3.
fn action_script_lexer_analyse(_text : String) -> Double {
  0.0
}

///|
let action_script3_import_re : @regex.Regex = @lexer.re("\\bimport\\s+flash\\.")

///|
fn action_script3_lexer_analyse(text : String) -> Double {
  if @lexer.search(action_script3_import_re, text) {
    0.2
  } else {
    0.0
  }
}
