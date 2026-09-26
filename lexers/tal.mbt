// Hand-written parts of pygments/lexers/tal.py.

///|
/// Python's `text[:n]` (counting code points).
fn tal_head(text : String, n : Int) -> String {
  let mut count = 0
  let mut end = 0
  for c in text {
    if count >= n {
      break
    }
    count += 1
    end += c.utf16_len()
  }
  text.unsafe_substring(start=0, end~)
}

///|
fn tal_lexer_analyse(text : String) -> Double {
  if tal_head(text, 500).contains("|0100") {
    1.0
  } else {
    0.0
  }
}
