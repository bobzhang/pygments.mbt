// Hand-written parts of pygments/lexers/prolog.py.

///|
/// Competes with IDL and Visual Prolog on `*.pro`.
fn prolog_lexer_analyse(text : String) -> Double {
  // Visual Prolog also uses :-
  if text.contains(":-") {
    0.5
  } else {
    0.0
  }
}

///|
let logtalk_directive_re : @regex.Regex = @lexer.re(
  "^:-\\s[a-z]",
  flags=@regex.MULTILINE,
)

///|
fn logtalk_lexer_analyse(text : String) -> Double {
  if text.contains(":- object(") {
    1.0
  } else if text.contains(":- protocol(") {
    1.0
  } else if text.contains(":- category(") {
    1.0
  } else if @lexer.search(logtalk_directive_re, text) {
    0.9
  } else {
    0.0
  }
}
