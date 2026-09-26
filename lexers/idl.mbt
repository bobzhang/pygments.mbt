// Hand-written parts of pygments/lexers/idl.py.

///|
/// `IDLLexer.analyse_text`: `endelse` seems unique to IDL, `endswitch` is
/// rare.
fn idl_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("endelse") {
    result += 0.2
  }
  if text.contains("endswitch") {
    result += 0.01
  }
  result
}
