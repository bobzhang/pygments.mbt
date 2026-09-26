///|
const MAX_CP : Int = 0x10FFFF

///|
/// An immutable set of code points: sorted, merged, inclusive ranges plus an
/// ASCII bitmap for the common fast path.
priv struct CharSet {
  ranges : FixedArray[Int]
  lo : UInt64
  hi : UInt64
  has_non_ascii : Bool
}

///|
fn CharSet::contains(self : CharSet, c : Int) -> Bool {
  if c < 64 {
    ((self.lo >> c) & 1) != 0
  } else if c < 128 {
    ((self.hi >> (c - 64)) & 1) != 0
  } else if !self.has_non_ascii {
    false
  } else {
    let r = self.ranges
    // binary search for the last range whose start <= c
    let mut lo = 0
    let mut hi = r.length() / 2 - 1
    while lo <= hi {
      let mid = (lo + hi) / 2
      if r[mid * 2] <= c {
        if c <= r[mid * 2 + 1] {
          return true
        }
        lo = mid + 1
      } else {
        hi = mid - 1
      }
    }
    false
  }
}

///|
/// Builds a `CharSet` from arbitrary (possibly overlapping) inclusive ranges.
fn CharSet::from_ranges(input : Array[(Int, Int)]) -> CharSet {
  let sorted = input.copy()
  sorted.sort_by((a, b) => if a.0 != b.0 { a.0 - b.0 } else { a.1 - b.1 })
  let merged : Array[Int] = []
  for r in sorted {
    let (a, b) = r
    let n = merged.length()
    if n > 0 && a <= merged[n - 1] + 1 {
      if b > merged[n - 1] {
        merged[n - 1] = b
      }
    } else {
      merged.push(a)
      merged.push(b)
    }
  }
  let mut lo : UInt64 = 0
  let mut hi : UInt64 = 0
  let mut has_non_ascii = false
  for i = 0; i < merged.length(); i = i + 2 {
    let a = merged[i]
    let b = merged[i + 1]
    if b >= 128 {
      has_non_ascii = true
    }
    let top = if b > 127 { 127 } else { b }
    for c = a; c <= top; c = c + 1 {
      if c < 64 {
        lo = lo | (1UL << c)
      } else {
        hi = hi | (1UL << (c - 64))
      }
    }
  }
  { ranges: FixedArray::from_array(merged), lo, hi, has_non_ascii, }
}

///|
fn CharSet::to_pairs(self : CharSet) -> Array[(Int, Int)] {
  let out = []
  for i = 0; i < self.ranges.length(); i = i + 2 {
    out.push((self.ranges[i], self.ranges[i + 1]))
  }
  out
}

///|
fn CharSet::complement(self : CharSet) -> CharSet {
  let out = []
  let mut next = 0
  for i = 0; i < self.ranges.length(); i = i + 2 {
    if self.ranges[i] > next {
      out.push((next, self.ranges[i] - 1))
    }
    next = self.ranges[i + 1] + 1
  }
  if next <= MAX_CP {
    out.push((next, MAX_CP))
  }
  CharSet::from_ranges(out)
}

///|
fn ranges_of_table(t : FixedArray[Int]) -> Array[(Int, Int)] {
  let out = []
  for i = 0; i < t.length(); i = i + 2 {
    out.push((t[i], t[i + 1]))
  }
  out
}

///|
let unicode_word : CharSet = CharSet::from_ranges(ranges_of_table(word_ranges))

///|
let unicode_digit : CharSet = CharSet::from_ranges(
  ranges_of_table(digit_ranges),
)

///|
let unicode_space : CharSet = CharSet::from_ranges(
  ranges_of_table(space_ranges),
)

///|
let ascii_word : CharSet = CharSet::from_ranges([
  (48, 57),
  (65, 90),
  (95, 95),
  (97, 122),
])

///|
let ascii_digit : CharSet = CharSet::from_ranges([(48, 57)])

///|
let ascii_space : CharSet = CharSet::from_ranges([(9, 13), (32, 32)])

///|
fn binary_search_table(t : FixedArray[Int], stride : Int, key : Int) -> Int {
  let mut lo = 0
  let mut hi = t.length() / stride - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let v = t[mid * stride]
    if v == key {
      return mid
    } else if v < key {
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  -1
}

///|
/// Python's `_sre.unicode_tolower` (simple lowercase mapping).
fn to_lower(c : Int) -> Int {
  if c < 128 {
    if c >= 65 && c <= 90 {
      c + 32
    } else {
      c
    }
  } else {
    let i = binary_search_table(lower_map, 2, c)
    if i < 0 {
      c
    } else {
      lower_map[i * 2 + 1]
    }
  }
}

///|
fn ascii_lower(c : Int) -> Int {
  if c >= 65 && c <= 90 {
    c + 32
  } else {
    c
  }
}

///|
/// All code points that match `c` under `re.IGNORECASE` (Unicode mode),
/// including `c` itself.
fn case_equivalents(c : Int) -> Array[Int] {
  let i = binary_search_table(case_equiv_keys, 1, c)
  if i < 0 {
    [c]
  } else {
    let out = []
    for j = case_equiv_offsets[i]; j < case_equiv_offsets[i + 1]; j = j + 1 {
      out.push(case_equiv_members[j])
    }
    out
  }
}

///|
/// Closes a set of ranges under case equivalence.
fn case_close(
  pairs : Array[(Int, Int)],
  ascii_only : Bool,
) -> Array[(Int, Int)] {
  let out = pairs.copy()
  if ascii_only {
    for r in pairs {
      let (a, b) = r
      // intersect with A-Z and a-z
      let a1 = if a > 65 { a } else { 65 }
      let b1 = if b < 90 { b } else { 90 }
      if a1 <= b1 {
        out.push((a1 + 32, b1 + 32))
      }
      let a2 = if a > 97 { a } else { 97 }
      let b2 = if b < 122 { b } else { 122 }
      if a2 <= b2 {
        out.push((a2 - 32, b2 - 32))
      }
    }
    return out
  }
  let set = CharSet::from_ranges(pairs)
  for i = 0; i < case_equiv_keys.length(); i = i + 1 {
    let k = case_equiv_keys[i]
    if set.contains(k) {
      for j = case_equiv_offsets[i]; j < case_equiv_offsets[i + 1]; j = j + 1 {
        let m = case_equiv_members[j]
        out.push((m, m))
      }
    }
  }
  out
}
