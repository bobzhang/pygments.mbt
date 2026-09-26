// Hand-written parts of pygments/lexers/nix.py.

///|
let nix_import_re : @regex.Regex = @lexer.re("import.+?<[^>]+>")

///|
let nix_mk_derivation_re : @regex.Regex = @lexer.re(
  "mkDerivation\\s+(\\(|\\{|rec)",
)

///|
let nix_mk_if_re : @regex.Regex = @lexer.re("=\\s+mkIf\\s+")

///|
let nix_lambda_re : @regex.Regex = @lexer.re("\\{[a-zA-Z,\\s]+\\}:")

///|
fn nix_lexer_analyse(text : String) -> Double {
  let mut rv = 0.0
  if @lexer.search(nix_import_re, text) {
    rv += 0.4
  }
  if @lexer.search(nix_mk_derivation_re, text) {
    rv += 0.4
  }
  if @lexer.search(nix_mk_if_re, text) {
    rv += 0.4
  }
  if @lexer.search(nix_lambda_re, text) {
    rv += 0.1
  }
  rv
}
