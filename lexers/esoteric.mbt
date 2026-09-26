// Hand-written parts of pygments/lexers/esoteric.py.

///|
/// A program which mostly consists of `+ -` and `< >` is brainfuck.
fn brainfuck_lexer_analyse(text : String) -> Double {
  let mut plus_minus_count = 0
  let mut greater_less_count = 0
  let mut len = 0
  for _ in text {
    len += 1
  }
  let range_to_check = if len > 256 { len } else { 256 }
  // `text[:range_to_check]` is the whole text
  for c in text {
    if c == '+' || c == '-' {
      plus_minus_count += 1
    }
    if c == '<' || c == '>' {
      greater_less_count += 1
    }
  }
  let limit = 0.25 * range_to_check.to_double()
  if plus_minus_count.to_double() > limit {
    return 1.0
  }
  if greater_less_count.to_double() > limit {
    return 1.0
  }
  if text.contains("[-]") {
    0.5
  } else {
    0.0
  }
}
