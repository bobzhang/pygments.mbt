///|
/// Replays the corpus produced by `scripts/lexer_oracle.py`: lexes every
/// input with the MoonBit port and compares the token stream with Python's.
///
/// Usage: lexer_oracle [corpus.jsonl] [-v] [--only ALIAS] [--quiet]
async fn main {
  let args = @env.args()
  let mut path = ".oracle/lexers.jsonl"
  let mut verbose = false
  let mut quiet = false
  let mut only : String? = None
  let mut i = 1
  while i < args.length() {
    match args[i] {
      "-v" => verbose = true
      "--quiet" => quiet = true
      "--only" => {
        i += 1
        only = Some(args[i])
      }
      p => path = p
    }
    i += 1
  }
  let data = @fs.read_file(path).text()
  let mut pass = 0
  let mut failed = 0
  let mut errors = 0
  let failed_by_alias : Map[String, Int] = Map([])
  let passed_by_alias : Map[String, Int] = Map([])
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line) catch {
      _ => {
        println("SKIP unparsable corpus line")
        continue
      }
    }
    guard json
      is {
        "file": String(file),
        "alias": String(alias),
        "input": String(input),
        "tokens": Array(expected),
        ..
      } else {
      fail("bad corpus line")
    }
    match only {
      Some(a) if a != alias => continue
      _ => ()
    }
    let want = expected.map(t => {
      guard t is Array([String(ty), String(v)]) else { ("?", "?") }
      (ty, v)
    })
    let got = try {
      let lx = @lexers.get_lexer_by_name(alias)
      lx
      .get_tokens(input)
      .map(t => {
        let s = t.0.to_string()
        (
          if s == "Token" {
            ""
          } else {
            s.unsafe_substring(start=6, end=s.length())
          },
          t.1,
        )
      })
    } catch {
      e => {
        errors += 1
        failed_by_alias[alias] = failed_by_alias.get(alias).unwrap_or(0) + 1
        if !quiet {
          println("ERROR \{file}: \{Repr(e)}")
        }
        continue
      }
    }
    if got == want {
      pass += 1
      passed_by_alias[alias] = passed_by_alias.get(alias).unwrap_or(0) + 1
    } else {
      failed += 1
      failed_by_alias[alias] = failed_by_alias.get(alias).unwrap_or(0) + 1
      if !quiet {
        let mut k = 0
        while k < got.length() && k < want.length() && got[k] == want[k] {
          k += 1
        }
        println("FAIL \{file} (token \{k} of \{want.length()})")
        let show = (xs : Array[(String, String)], j : Int) => {
          if j < xs.length() {
            "\{xs[j].0} \{xs[j].1.escape()}"
          } else {
            "<end>"
          }
        }
        println("  want: \{show(want, k)}")
        println("  got : \{show(got, k)}")
        if verbose {
          for j = k + 1; j < k + 5; j = j + 1 {
            println("  want: \{show(want, j)} | got: \{show(got, j)}")
          }
        }
      }
    }
  }
  let failing = failed_by_alias.keys().collect()
  failing.sort()
  println(
    "cases: pass=\{pass} fail=\{failed} error=\{errors}; lexers failing: \{failing.length()}",
  )
  if !quiet {
    println("failing: \{failing.join(" ")}")
  }
}
