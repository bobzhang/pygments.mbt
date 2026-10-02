///|
fn all_spans(re : @regex.Regex, text : String) -> Array[Array[Int]] raise {
  re
  .find_all(text)
  .map(m => {
    let out = []
    for g in 0..<=m.group_count() {
      out.push(m.start(group=g))
      out.push(m.end(group=g))
    }
    out
  })
}

///|
/// `[[a, b], [c, d]]` on one line.
fn compact(xs : Array[Array[Int]]) -> String {
  "[" +
  xs.map(x => "[" + x.map(n => n.to_string()).join(", ") + "]").join(", ") +
  "]"
}

///|
test "groups of an earlier match do not leak into later ones" {
  let re = @regex.compile("(a)|(b)(c)?|(?P<d>d+)")
  debug_inspect(
    all_spans(re, "abcbdd"),
    content=(
      #|[
      #|  [0, 1, 0, 1, -1, -1, -1, -1, -1, -1],
      #|  [1, 3, -1, -1, 1, 2, 2, 3, -1, -1],
      #|  [3, 4, -1, -1, 3, 4, -1, -1, -1, -1],
      #|  [4, 6, -1, -1, -1, -1, -1, -1, 4, 6],
      #|]
    ),
  )
  // match_at after a find_all reuses the same VM
  debug_inspect(
    spans(re, "xb", pos=1),
    content="Some([1, 2, -1, -1, 1, 2, -1, -1, -1, -1])",
  )
  // a nullable group inside a loop (register slots)
  let loop_re = @regex.compile("(?:(x*)y)*z")
  debug_inspect(
    all_spans(loop_re, "xyyz z"),
    content="[[0, 4, 2, 2], [5, 6, -1, -1]]",
  )
}

///|
test "search skips impossible starts and handles surrogate pairs" {
  let re = @regex.compile("\\b(?:ERROR|FATAL)\\b: (?P<msg>.*)")
  debug_inspect(
    all_spans(re, "ok\nan ERRORS: no\nFATAL: disk 😀\n"),
    content="[[17, 31, 24, 31]]",
  )
  let emoji = @regex.compile("😀+|x")
  debug_inspect(all_spans(emoji, "a😀😀bx"), content="[[1, 5], [6, 7]]")
  // empty matches advance by code point
  let empty = @regex.compile("(?=😀)|$")
  debug_inspect(all_spans(empty, "a😀b"), content="[[1, 1], [4, 4]]")
}

///|
test "search budget covers the whole scan" {
  let re = @regex.compile("(a*)*b")
  let text = "x" + "a".repeat(30)
  try re.search(text, budget=@regex.Budget::new(100000)) catch {
    BudgetExceeded(..) => ()
    e => fail("unexpected \{Repr(e)}")
  } noraise {
    _ => fail("expected budget exhaustion")
  }
  // positions ruled out by the prefilter are charged one step each
  let lit = @regex.compile("z")
  try lit.search("y".repeat(1000), budget=@regex.Budget::new(500)) catch {
    BudgetExceeded(..) => ()
    e => fail("unexpected \{Repr(e)}")
  } noraise {
    _ => fail("expected budget exhaustion")
  }
  let budget = @regex.Budget::new(5000)
  debug_inspect(
    lit.search("y".repeat(1000) + "z", budget~) is Some(_),
    content="true",
  )
  inspect(budget.remaining, content="3998")
}

///|
test "repetitions guarded by the characters that follow them" {
  // expected values from CPython's re.finditer (UTF-16 offsets)
  let cases : Array[(String, String, String)] = [
    (
      "a{1,3}?(b)", "aaab aaaab ab", "[[0, 4, 3, 4], [6, 10, 9, 10], [11, 13, 12, 13]]",
    ),
    ("\\w+?(?<!x)=", "kx=ky= a=", "[[3, 6], [7, 9]]"),
    ("[^ ]*(?=😀)😀", "ab😀 c😀😀", "[[0, 4], [5, 10]]"),
    ("x.{0,2}?😀", "x😀 xab😀 xabc😀", "[[0, 3], [4, 9]]"),
    ("(?<=😀)b|(?<!a)c", "😀b ac bc", "[[2, 3], [8, 9]]"),
    ("(\\w+)\\s*(?:=|:)", "key = 1, other: 2", "[[0, 5, 0, 3], [9, 15, 9, 14]]"),
    ("\"(?:[^\"\\\\]|\\\\.)*\"", "say \"a\\\"b\" ok", "[[4, 10]]"),
  ]
  for case in cases {
    let (pattern, text, expected) = case
    let got = all_spans(@regex.compile(pattern), text)
    assert_eq(compact(got), expected)
  }
}

///|
test "search skips starts inside a failed leading repetition" {
  // expected values from CPython's re.finditer (UTF-16 offsets)
  let cases : Array[(String, String, String)] = [
    // stopped at its maximum: no skipping
    ("\\w{1,3}=", "abcdef= x=1", "[[3, 7], [8, 10]]"),
    // backreferences depend on the start: no skipping
    ("(\\w+)\\1", "abcbc xyzz", "[[1, 5, 1, 3], [8, 10, 8, 9]]"),
    (
      "(?P<a>[\\w_]{1,50})=(?P<v>\"?[\\w_]+\"?)?", "foo bar=1 baz_qux=\"x\" =", "[[4, 9, 4, 7, 8, 9], [10, 21, 10, 17, 18, 21]]",
    ),
    ("[a-z]+(?<=cd)e", "abcde xcde", "[[0, 5], [6, 10]]"),
    ("\\w+?=", "aaa= b=", "[[0, 4], [5, 7]]"),
    ("[a-z]{2,}\\d", "a1 ab1 abc 1abc2", "[[3, 6], [12, 16]]"),
    ("\\w+(?=😀)", "ab😀cd 😀", "[[0, 2]]"),
  ]
  for case in cases {
    let (pattern, text, expected) = case
    let got = all_spans(@regex.compile(pattern), text)
    assert_eq(compact(got), expected)
  }
}

///|
test "leading assertions and optional repetitions before a guard" {
  // expected values from CPython's re.finditer (UTF-16 offsets)
  let cases : Array[(String, String, String)] = [
    (
      "(?m)(^[ \\t]*)(match|case)\\b", "  match x\nmatch\n case", "[[0, 7, 0, 2, 2, 7], [10, 15, 10, 10, 10, 15], [16, 21, 16, 17, 17, 21]]",
    ),
    (
      "(?m)^(\\s*)([rRuUbB]{,2})('''[\\s\\S]*?''')", "x\n  r'''a'''\n\n   '''b'''",
      "[[2, 12, 2, 4, 4, 5, 5, 12], [13, 24, 13, 17, 17, 17, 17, 24]]",
    ),
    (
      "((?:^a)*)(b)", "aab ab b", "[[2, 3, 2, 2, 2, 3], [5, 6, 5, 5, 5, 6], [7, 8, 7, 7, 7, 8]]",
    ),
    ("(\\b)(\\w+)", "ab cd", "[[0, 2, 0, 0, 0, 2], [3, 5, 3, 3, 3, 5]]"),
    // guards through alternatives
    (
      "(?m)(^[ \\t]*)(match|case)\\b", "    x\n  case y\n\tmatch", "[[6, 12, 6, 8, 8, 12], [15, 21, 15, 16, 16, 21]]",
    ),
    ("[ab]*(?:cd|e)", "aab abcd xe", "[[4, 8], [10, 11]]"),
    ("\\s*(?:(?:x|y)z|w)", "  yz w  xw", "[[0, 4], [4, 6], [9, 10]]"),
  ]
  for case in cases {
    let (pattern, text, expected) = case
    let got = all_spans(@regex.compile(pattern), text)
    assert_eq(compact(got), expected)
  }
}
