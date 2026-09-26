///|
/// Whether `cp` lies in one of the inclusive `ranges` (pairs, sorted).
fn in_ranges(ranges : FixedArray[Int], cp : Int) -> Bool {
  let mut lo = 0
  let mut hi = ranges.length() / 2 - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    if cp < ranges[2 * mid] {
      hi = mid - 1
    } else if cp > ranges[2 * mid + 1] {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
/// Python's `str.isprintable` for one character.
pub fn is_printable(c : Char) -> Bool {
  !in_ranges(nonprintable_ranges, c.to_int())
}

///|
/// Whether `c` is cased (Unicode `Cased` property, as used by Python).
pub fn is_cased(c : Char) -> Bool {
  in_ranges(cased_ranges, c.to_int())
}

///|
/// Whether `c` is case-ignorable (Unicode `Case_Ignorable`).
pub fn is_case_ignorable(c : Char) -> Bool {
  in_ranges(case_ignorable_ranges, c.to_int())
}

///|
let case_map : Map[Int, (String, String, String)] = Map([])

///|
/// The full `(lower, upper, title)` mappings of `c`, if any differs from `c`.
fn case_entry(c : Char) -> (String, String, String)? {
  if case_map.is_empty() {
    for row in case_table {
      case_map[row.0] = (row.1, row.2, row.3)
    }
  }
  case_map.get(c.to_int())
}
