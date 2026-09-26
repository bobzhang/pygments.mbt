// Hand-written parts of pygments/lexers/basic.py.

///|
let cbm_basic_line_number_re : @regex.Regex = @lexer.re("^\\d+")

///|
fn cbm_basic_v2_lexer_analyse(text : String) -> Double {
  // if it starts with a line number, it shouldn't be a "modern" Basic
  if @lexer.matches(cbm_basic_line_number_re, text) {
    0.2
  } else {
    0.0
  }
}

///|
fn q_basic_lexer_analyse(text : String) -> Double {
  if text.contains("$DYNAMIC") || text.contains("$STATIC") {
    0.9
  } else {
    0.0
  }
}

///|
fn bbc_basic_lexer_analyse(text : String) -> Double {
  if text.has_prefix("10REM >") || text.has_prefix("REM >") {
    0.9
  } else {
    0.0
  }
}
