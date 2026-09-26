///|
fn spans(re : @regex.Regex, text : String, pos? : Int = 0) -> Array[Int]? raise {
  match re.match_at(text, pos) {
    None => None
    Some(m) => {
      let out = []
      for g in 0..<=m.group_count() {
        out.push(m.start(group=g))
        out.push(m.end(group=g))
      }
      Some(out)
    }
  }
}

///|
test "alternation is ordered (leftmost-first)" {
  debug_inspect(spans(@regex.compile("a|ab"), "abc"), content="Some([0, 1])")
  debug_inspect(
    spans(@regex.compile("(?:x|xy)*y"), "xyy"),
    content="Some([0, 2])",
  )
}

///|
test "anchors honour MULTILINE and the real string start" {
  let bol = @regex.compile("^b", flags=@regex.MULTILINE)
  debug_inspect(spans(bol, "a\nb", pos=2), content="Some([2, 3])")
  debug_inspect(spans(bol, "ab", pos=1), content="None")
  let eol = @regex.compile("a$")
  debug_inspect(spans(eol, "a\n"), content="Some([0, 1])")
  debug_inspect(spans(eol, "a\nb"), content="None")
}

///|
test "lookaround, backreferences and conditionals" {
  debug_inspect(
    spans(@regex.compile("(?<=\\$)\\w+"), "$foo", pos=1),
    content="Some([1, 4])",
  )
  debug_inspect(spans(@regex.compile("foo(?!bar)"), "foobar"), content="None")
  debug_inspect(
    spans(@regex.compile("(['\"])(.*?)\\1"), "'a\"b' x"),
    content="Some([0, 5, 0, 1, 1, 4])",
  )
  let cond = @regex.compile("(<)?\\w+(?(1)>)")
  debug_inspect(spans(cond, "<a>"), content="Some([0, 3, 0, 1])")
  debug_inspect(spans(cond, "a>"), content="Some([0, 1, -1, -1])")
}

///|
test "unicode classes, ignorecase and surrogate pairs" {
  debug_inspect(
    spans(@regex.compile("\\w+"), "héllo wörld"),
    content="Some([0, 5])",
  )
  debug_inspect(
    spans(@regex.compile("k", flags=@regex.IGNORECASE), "\u{212A}"),
    content="Some([0, 1])",
  )
  // one code point, two UTF-16 units
  debug_inspect(spans(@regex.compile("."), "😀"), content="Some([0, 2])")
  debug_inspect(
    spans(@regex.compile("(?<=😀)x"), "😀x", pos=2),
    content="Some([2, 3])",
  )
}

///|
test "verbose patterns and scoped flags" {
  let re = @regex.compile(
    (
      #|(?x) \d+   # digits
      #|  (?i: [a-f] )+
    ),
  )
  debug_inspect(spans(re, "12AbZ"), content="Some([0, 4])")
}

///|
test "budget exhaustion is an error, not a failed match" {
  let re = @regex.compile("(a*)*b")
  let text = "a".repeat(40)
  try re.match_at(text, 0, budget=@regex.Budget::new(10000)) catch {
    BudgetExceeded(..) => ()
    e => fail("unexpected \{Repr(e)}")
  } noraise {
    _ => fail("expected budget exhaustion")
  }
}

///|
test "syntax errors" {
  try @regex.compile("a**") catch {
    Syntax(message~, ..) => inspect(message, content="multiple repeat")
    _ => fail("unexpected")
  } noraise {
    _ => fail("expected error")
  }
  try @regex.compile("(?<=a+)b") catch {
    Syntax(message~, ..) =>
      inspect(message, content="look-behind requires fixed-width pattern")
    _ => fail("unexpected")
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "search, find_all and replace_all" {
  let re = @regex.compile("\\d+")
  guard re.search("ab12cd345") is Some(m) else { fail("no match") }
  inspect(m.matched(), content="12")
  inspect(
    re.find_all("ab12cd345").map(m => m.matched()).join(","),
    content="12,345",
  )
  inspect(re.replace_all("a1b22", _ => "#"), content="a#b#")
}
