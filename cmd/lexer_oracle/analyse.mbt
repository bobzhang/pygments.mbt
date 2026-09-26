///|
/// Compares `analyse_text` scores and `guess_lexer` results with
/// `.oracle/analyse.jsonl` (see `scripts/analyse_oracle.py`).
async fn run_analyse(path : String, only : String?, quiet : Bool) -> Unit {
  let data = @fs.read_file(path).text()
  let score_bad : Map[String, Int] = Map([])
  let mut guess_ok = 0
  let mut guess_bad = 0
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line) catch { _ => continue }
    guard json
      is {
        "file": String(file),
        "input": String(input),
        "scores": Object(scores),
        "guess": guess,
        ..
      } else {
      continue
    }
    for entry in @lexers.all_lexers {
      let info = entry.0
      match only {
        Some(c) if c != info.class_name => continue
        _ => ()
      }
      let want = match scores.get(info.class_name) {
        Some(Number(x, ..)) => x
        _ => 0.0
      }
      let got = @lexer.clamp_score((info.analyse_text)(input))
      if (got - want).abs() > 1.0e-9 {
        score_bad[info.class_name] = score_bad.get(info.class_name).unwrap_or(0) +
          1
        if !quiet {
          println("SCORE \{info.class_name} \{file}: want \{want} got \{got}")
        }
      }
    }
    if only is None {
      let want_guess = match guess {
        String(s) => s
        _ => "<none>"
      }
      let got_guess = @lexers.guess_lexer(input).info.class_name catch {
          _ => "<none>"
        }
      if want_guess == got_guess {
        guess_ok += 1
      } else {
        guess_bad += 1
        if !quiet {
          println("GUESS \{file}: want \{want_guess} got \{got_guess}")
        }
      }
    }
  }
  let bad = score_bad.keys().collect()
  bad.sort()
  println(
    "analyse: \{bad.length()} lexers with wrong scores; guess ok=\{guess_ok} bad=\{guess_bad}",
  )
  if !quiet {
    println("wrong scores: \{bad.join(" ")}")
  }
  if bad.length() > 0 || guess_bad > 0 {
    @sys.exit(1)
  }
}
