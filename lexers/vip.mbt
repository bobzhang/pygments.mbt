// Hand-written parts of pygments/lexers/vip.py.

///|
let visual_prolog_indicator_re : @regex.Regex = @lexer.re(
  "^\\s*(end\\s+(interface|class|implement)|(clauses|predicates|domains|facts|constants|properties)\\s*$)",
)

///|
let visual_prolog_grammar_indicator_re : @regex.Regex = @lexer.re(
  "^\\s*(end\\s+grammar|(nonterminals|startsymbols|terminals|rules|precedence)\\s*$)",
)

///|
/// Competes with IDL and Prolog on `*.pro`, Lisps on `*.cl` and SWIG on `*.i`.
fn visual_prolog_lexer_analyse(text : String) -> Double {
  if @lexer.search(visual_prolog_indicator_re, text) {
    0.98
  } else {
    0.0
  }
}

///|
fn visual_prolog_grammar_lexer_analyse(text : String) -> Double {
  if @lexer.search(visual_prolog_grammar_indicator_re, text) {
    0.98
  } else {
    0.0
  }
}
