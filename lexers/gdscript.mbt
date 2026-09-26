// Hand-written parts of pygments/lexers/gdscript.py.

///|
let gdscript_callback_re : @regex.Regex = @lexer.re(
  "func (_ready|_init|_input|_process|_unhandled_input)",
)

///|
let gdscript_keyword_re : @regex.Regex = @lexer.re(
  "(extends |class_name |onready |preload|load|setget|func [^_])",
)

///|
let gdscript_decl_re : @regex.Regex = @lexer.re(
  "(var|const|enum|export|signal|tool)",
)

///|
fn gd_script_lexer_analyse(text : String) -> Double {
  let mut score = 0.0
  if @lexer.search(gdscript_callback_re, text) {
    score += 0.8
  }
  if @lexer.search(gdscript_keyword_re, text) {
    score += 0.4
  }
  if @lexer.search(gdscript_decl_re, text) {
    score += 0.2
  }
  if score > 1.0 {
    1.0
  } else {
    score
  }
}
