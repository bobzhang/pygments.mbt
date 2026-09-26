// Hand-written parts of pygments/lexers/teraterm.py.
// pydata: teraterm_commands_pattern = L.teraterm.TeraTermLexer.tokens['commands'][0][0]

///|
let teraterm_commands_re : @regex.Regex = @lexer.re(teraterm_commands_pattern)

///|
fn tera_term_lexer_analyse(text : String) -> Double {
  if @lexer.search(teraterm_commands_re, text) {
    0.01
  } else {
    0.0
  }
}
