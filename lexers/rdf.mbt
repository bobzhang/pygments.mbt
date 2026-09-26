// Hand-written parts of pygments/lexers/rdf.py.

///|
let turtle_directive_res : Array[@regex.Regex] = [
  "@base ", "BASE ", "@prefix ", "PREFIX ",
].map(t => @lexer.re("^\\s*" + t))

///|
fn turtle_lexer_analyse(text : String) -> Double {
  for r in turtle_directive_res {
    if @lexer.search(r, text) {
      return 0.8
    }
  }
  0.0
}
