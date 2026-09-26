///|
/// Replays the corpus produced by `scripts/regex_oracle.py` and reports
/// mismatches between the MoonBit engine and Python's `re`.
async fn main {
  let args = @env.args()
  let path = if args.length() > 1 { args[1] } else { ".oracle/regex.jsonl" }
  let verbose = args.contains("-v")
  let data = @fs.read_file(path).text()
  let lines = data.split("\n").to_array()
  guard @json.parse(lines[0]) is { "texts": Array(texts_json), .. } else {
    fail("bad header")
  }
  let texts = texts_json.map(t => {
    guard t is String(s) else { "" }
    s
  })
  let mut patterns = 0
  let mut compile_errors = 0
  let mut cases = 0
  let mut mismatches = 0
  let mut bad_patterns = 0
  for i in 1..<lines.length() {
    let line = lines[i]
    if line.trim().length() == 0 {
      continue
    }
    guard @json.parse(line)
      is { "p": String(pat), "f": Number(f, ..), "c": Array(cs), .. } else {
      fail("bad line \{i}")
    }
    patterns += 1
    let re = @regex.compile(pat, flags=f.to_int()) catch {
      e => {
        compile_errors += 1
        println("COMPILE \{pat.escape()} flags=\{f}: \{Repr(e)}")
        continue
      }
    }
    let mut bad = false
    for c in cs {
      guard c is Array([Number(tid, ..), Number(pos, ..), expected]) else {
        fail("bad case")
      }
      cases += 1
      let text = texts[tid.to_int()]
      let got : Array[Int]? = try re.match_at(text, pos.to_int()) catch {
        e => {
          println("ERROR \{pat.escape()}: \{Repr(e)}")
          Some([-99])
        }
      } noraise {
        Some(m) => {
          let spans = []
          for g in 0..<=m.group_count() {
            spans.push(m.start(group=g))
            spans.push(m.end(group=g))
          }
          Some(spans)
        }
        None => None
      }
      let want : Array[Int]? = match expected {
        Null => None
        Array(xs) =>
          Some(
            xs.map(x => {
              guard x is Number(n, ..) else { 0 }
              n.to_int()
            }),
          )
        _ => None
      }
      if got != want {
        mismatches += 1
        if !bad || verbose {
          println(
            "MISMATCH \{pat.escape()} flags=\{f} text=\{tid} pos=\{pos}\n  want=\{Repr(want)}\n  got =\{Repr(got)}\n  at: \{text.unsafe_substring(start=pos.to_int(), end=@cmp.minimum(text.length(), pos.to_int() + 40)).escape()}",
          )
        }
        bad = true
      }
    }
    if bad {
      bad_patterns += 1
    }
  }
  println(
    "patterns=\{patterns} compile_errors=\{compile_errors} cases=\{cases} mismatches=\{mismatches} bad_patterns=\{bad_patterns}",
  )
  if compile_errors > 0 || mismatches > 0 {
    @sys.exit(1)
  }
}
