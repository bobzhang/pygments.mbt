// Hand-written parts of pygments/lexers/dalvik.py.

///|
let smali_class_re : @regex.Regex = @lexer.re(
  "^\\s*\\.class\\s",
  flags=@regex.MULTILINE,
)

///|
let smali_insn_re : @regex.Regex = @lexer.re(
  "\\b((check-cast|instance-of|throw-verification-error)\\b|(-to|add|[ais]get|[ais]put|and|cmpl|const|div|if|invoke|move|mul|neg|not|or|rem|return|rsub|shl|shr|sub|ushr)[-/])|{|}",
  flags=@regex.MULTILINE,
)

///|
let smali_keyword_re : @regex.Regex = @lexer.re(
  "(\\.(catchall|epilogue|restart local|prologue)|\\b(array-data|class-change-error|declared-synchronized|(field|inline|vtable)@0x[0-9a-fA-F]|generic-error|illegal-class-access|illegal-field-access|illegal-method-access|instantiation-error|no-error|no-such-class|no-such-field|no-such-method|packed-switch|sparse-switch))\\b",
  flags=@regex.MULTILINE,
)

///|
fn smali_lexer_analyse(text : String) -> Double {
  let mut score = 0.0
  if @lexer.search(smali_class_re, text) {
    score += 0.5
    if @lexer.search(smali_insn_re, text) {
      score += 0.3
    }
  }
  if @lexer.search(smali_keyword_re, text) {
    score += 0.6
  }
  score
}
