// Hand-written parts of pygments/lexers/asm.py.
// pydata: dasm16_registers = L.asm.Dasm16Lexer.REGISTERS

///|
/// Callbacks of `Dasm16Lexer`: `guess_identifier` tags register names as
/// variables and anything else as labels.
fn dasm16_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    (
      "Dasm16Lexer.guess_identifier",
      (ctx, m, _) => {
        let ident = m.matched()
        let klass = if dasm16_registers.contains(ident.to_upper()) {
          @token.name_variable
        } else {
          @token.name_label
        }
        ctx.emit(m.start(), klass, ident)
      },
    ),
  ])
}

///|
let gas_section_re : @regex.Regex = @lexer.re(
  "^\\.(text|data|section)",
  flags=@regex.MULTILINE,
)

///|
let gas_directive_re : @regex.Regex = @lexer.re(
  "^\\.\\w+",
  flags=@regex.MULTILINE,
)

///|
fn gas_lexer_analyse(text : String) -> Double {
  if @lexer.search(gas_section_re, text) {
    1.0
  } else if @lexer.search(gas_directive_re, text) {
    0.1
  } else {
    0.0
  }
}

///|
let asm_proc_re : @regex.Regex = @lexer.re("PROC", flags=@regex.IGNORECASE)

///|
/// `NasmLexer.analyse_text` returns `False` or `None`: always 0.
fn nasm_lexer_analyse(_text : String) -> Double {
  0.0
}

///|
/// `TasmLexer.analyse_text`: the text starts with `PROC`.
fn tasm_lexer_analyse(text : String) -> Double {
  if @lexer.matches(asm_proc_re, text) {
    1.0
  } else {
    0.0
  }
}

///|
/// `Ca65Lexer.analyse_text` is declared with a `self` parameter, so calling
/// it with the text alone raises `TypeError`, which `make_analysator` turns
/// into 0.
fn ca65_lexer_analyse(_text : String) -> Double {
  0.0
}
