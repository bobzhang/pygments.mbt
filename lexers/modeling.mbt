// Hand-written parts of pygments/lexers/modeling.py.

///|
let modeling_model_re : @regex.Regex = @lexer.re(
  "^\\s*model\\s*\\{",
  flags=@regex.MULTILINE,
)

///|
let modeling_data_re : @regex.Regex = @lexer.re(
  "^\\s*data\\s*\\{",
  flags=@regex.MULTILINE,
)

///|
let modeling_var_re : @regex.Regex = @lexer.re(
  "^\\s*var",
  flags=@regex.MULTILINE,
)

///|
let modeling_parameters_re : @regex.Regex = @lexer.re(
  "^\\s*parameters\\s*\\{",
  flags=@regex.MULTILINE,
)

///|
fn bugs_lexer_analyse(text : String) -> Double {
  if @lexer.search(modeling_model_re, text) {
    0.7
  } else {
    0.0
  }
}

///|
fn jags_lexer_analyse(text : String) -> Double {
  if @lexer.search(modeling_model_re, text) {
    if @lexer.search(modeling_data_re, text) {
      0.9
    } else if @lexer.search(modeling_var_re, text) {
      0.9
    } else {
      0.3
    }
  } else {
    0.0
  }
}

///|
fn stan_lexer_analyse(text : String) -> Double {
  if @lexer.search(modeling_parameters_re, text) {
    1.0
  } else {
    0.0
  }
}
