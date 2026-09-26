// Hand-written parts of pygments/lexers/hdl.py.

///|
/// `VerilogLexer.analyse_text`: `reg`, `wire` and `assign` are common in
/// Verilog and rare elsewhere.
fn verilog_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  for word in ["reg", "wire", "assign"] {
    if text.contains(word) {
      result += 0.1
    }
  }
  result
}
