///|
let capital_sigma : Char = '\u{3a3}'

///|
/// Python's final-sigma rule: whether the capital sigma at `chars[i]`
/// lowercases to `ς`.
fn is_final_sigma(chars : Array[Char], i : Int) -> Bool {
  let mut j = i - 1
  while j >= 0 && is_case_ignorable(chars[j]) {
    j -= 1
  }
  if j < 0 || !is_cased(chars[j]) {
    return false
  }
  j = i + 1
  while j < chars.length() && is_case_ignorable(chars[j]) {
    j += 1
  }
  j == chars.length() || !is_cased(chars[j])
}

///|
fn lower_at(chars : Array[Char], i : Int, buf : StringBuilder) -> Unit {
  let c = chars[i]
  if c == capital_sigma {
    buf.write_char(if is_final_sigma(chars, i) { '\u{3c2}' } else { '\u{3c3}' })
  } else if c.to_int() < 0x80 {
    buf.write_char(
      if c >= 'A' && c <= 'Z' {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  } else {
    match case_entry(c) {
      Some((lo, _, _)) => buf.write_string(lo)
      None => buf.write_char(c)
    }
  }
}

///|
/// Python's `str.lower` (full Unicode case mapping, final-sigma rule).
///
/// ```mbt check
/// test {
///   inspect(@pystr.lower("ÀBΣ ΟΔΟΣ"), content="àbς οδος")
/// }
/// ```
pub fn lower(s : String) -> String {
  let chars = s.to_array()
  let buf = StringBuilder()
  for i in 0..<chars.length() {
    lower_at(chars, i, buf)
  }
  buf.to_string()
}

///|
/// Python's `str.upper` (full Unicode case mapping).
///
/// ```mbt check
/// test {
///   inspect(@pystr.upper("straße"), content="STRASSE")
/// }
/// ```
pub fn upper(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if c.to_int() < 0x80 {
      buf.write_char(
        if c >= 'a' && c <= 'z' {
          (c.to_int() - 32).unsafe_to_char()
        } else {
          c
        },
      )
    } else {
      match case_entry(c) {
        Some((_, up, _)) => buf.write_string(up)
        None => buf.write_char(c)
      }
    }
  }
  buf.to_string()
}

///|
/// Python's `str.capitalize`: the first character in title case, the rest
/// lowercased.
///
/// ```mbt check
/// test {
///   inspect(@pystr.capitalize("hELLO"), content="Hello")
///   inspect(@pystr.capitalize("ǆemal"), content="ǅemal")
/// }
/// ```
pub fn capitalize(s : String) -> String {
  let chars = s.to_array()
  let buf = StringBuilder()
  for i in 0..<chars.length() {
    if i == 0 {
      let c = chars[0]
      match case_entry(c) {
        Some((_, _, title)) => buf.write_string(title)
        None => buf.write_char(c)
      }
    } else {
      lower_at(chars, i, buf)
    }
  }
  buf.to_string()
}
