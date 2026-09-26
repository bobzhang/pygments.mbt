///|
/// Pass/fail counters per case group (`format:html`, `style`, ...).
struct Tally {
  pass : Map[String, Int]
  fail : Map[String, Int]
}

///|
fn Tally::add(self : Tally, group : String, ok : Bool) -> Unit {
  let m = if ok { self.pass } else { self.fail }
  m[group] = m.get(group).unwrap_or(0) + 1
}

///|
/// Runs one case: `produce` computes the MoonBit result, which is compared
/// with the expected `output` (or the expectation of an error).
fn check_case(
  tally : Tally,
  group : String,
  desc : String,
  json : Map[String, Json],
  quiet : Bool,
  produce : () -> String raise,
) -> Unit {
  let expected_error = json.get("error")
  let result : Result[String, String] = try produce() |> Ok catch {
    e => Err("\{e}")
  }
  match (result, expected_error, json.get("output")) {
    (Err(_), Some(_), _) => tally.add(group, true)
    (Ok(got), None, Some(String(want))) =>
      if got == want {
        tally.add(group, true)
      } else {
        tally.add(group, false)
        if !quiet {
          let i = first_diff(got, want)
          println(
            "FAIL \{desc} at \{i} (got \{got.length()}, want \{want.length()})",
          )
          println("  want: \{excerpt(want, i)}")
          println("  got : \{excerpt(got, i)}")
        }
      }
    (Ok(_), Some(String(err)), _) => {
      tally.add(group, false)
      if !quiet {
        println("FAIL \{desc}: expected error \{err}")
      }
    }
    (Err(e), None, _) => {
      tally.add(group, false)
      if !quiet {
        println("ERROR \{desc}: \{e}")
      }
    }
    _ => {
      tally.add(group, false)
      println("BAD corpus line \{desc}")
    }
  }
}

///|
/// Serialises a token stream like the corpus does, for comparison.
fn tokens_json_string(tokens : Array[(@token.TokenType, String)]) -> String {
  Json::array(
    tokens.map(t => {
      Json::array([Json::string(t.0.to_string()), Json::string(t.1)])
    }),
  ).stringify()
}

///|
/// Replays the corpus produced by `scripts/formatter_oracle.py`: formats the
/// stored token streams with the MoonBit formatters (and checks styles,
/// style definitions and filters), comparing byte for byte with Python.
///
/// Usage: formatter_oracle [corpus.jsonl] [--only GROUP] [--quiet]
///   GROUP is e.g. `format:html`, `styledefs:latex`, `style`, `filter:gobble`.
async fn main {
  let args = @env.args()
  let mut path = ".oracle/formatters.jsonl"
  let mut quiet = false
  let mut only : String? = None
  let mut i = 1
  while i < args.length() {
    match args[i] {
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
  let token_sets : Map[String, Array[(@token.TokenType, String)]] = Map([])
  let tally = { pass: Map([]), fail: Map([]), }
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
    guard json is Object(obj) && obj.get("kind") is Some(String(kind)) else {
      println("SKIP bad corpus line")
      continue
    }
    let id = match obj.get("id") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    }
    let tokens = match obj.get("tokens") {
      Some(String(key)) => token_sets.get(key).unwrap_or([])
      _ => []
    }
    let tokens_key = match obj.get("tokens") {
      Some(String(key)) => key
      _ => ""
    }
    let options = decode_options(obj.get("options"))
    let group = match kind {
      "format" | "styledefs" =>
        match obj.get("formatter") {
          Some(String(f)) => kind + ":" + f
          _ => kind
        }
      "filter" =>
        match obj.get("filter") {
          Some(String(f)) => kind + ":" + f
          _ => kind
        }
      _ => kind
    }
    match only {
      Some(o) if kind != "tokens" && o != group && o != kind => continue
      _ => ()
    }
    let desc = "#\{id} \{group} \{tokens_key} \{options.to_array().map(p => p.0 + "=" + p.1).join(",")}"
    match kind {
      "tokens" =>
        match (obj.get("key"), obj.get("tokens")) {
          (Some(String(key)), Some(toks)) =>
            token_sets[key] = decode_tokens(toks)
          _ => println("SKIP bad tokens line")
        }
      "style" => {
        guard obj.get("name") is Some(String(name)) else { continue }
        let ok = try {
          let st = @styles.get_style_by_name(name)
          let entries = st
            .list_styles()
            .map(e => {
              Json::array([Json::string(e.0.to_string()), token_style_json(e.1)])
            })
          Some(style_attrs_json(st)) == obj.get("attrs") &&
          Some(Json::array(entries)) == obj.get("entries")
        } catch {
          _ => false
        }
        tally.add("style", ok)
        if !ok && !quiet {
          println("FAIL style \{name}")
        }
      }
      "format" => {
        guard obj.get("formatter") is Some(String(alias_)) else { continue }
        check_case(tally, group, desc, obj, quiet, () => {
          let f = @formatters.get_formatter_by_name(alias_, options~)
          f.format(tokens)
        })
      }
      "cssfile" =>
        check_case(tally, "cssfile:html", desc, obj, quiet, () => {
          let f = @formatters.get_formatter_by_name("html", options~)
          ignore(f.format(tokens))
          match f.aux_files() {
            [file] => file.contents
            _ => "<no aux file>"
          }
        })
      "styledefs" => {
        guard obj.get("formatter") is Some(String(alias_)) else { continue }
        check_case(tally, group, desc, obj, quiet, () => {
          match (obj.get("args"), obj.get("arg")) {
            (Some(Array(items)), _) => {
              let sel = items.map(a => if a is String(s) { s } else { "" })
              @formatters.HtmlFormatter::new(options~).get_style_defs_for(sel)
            }
            (_, Some(String(arg))) =>
              @formatters.get_formatter_by_name(alias_, options~).get_style_defs(
                arg~,
              )
            _ =>
              @formatters.get_formatter_by_name(alias_, options~).get_style_defs()
          }
        })
      }
      "filter" => {
        guard obj.get("filter") is Some(String(name)) else { continue }
        let obj2 = obj.copy()
        match obj.get("output") {
          Some(out) => obj2["output"] = Json::string(out.stringify())
          None => ()
        }
        check_case(tally, group, desc, obj2, quiet, () => {
          let f = @filters.get_filter_by_name(name, options~)
          tokens_json_string((f.apply)(None, tokens))
        })
      }
      "lexer" => {
        guard obj
          is {
            "left": String(left),
            "right": String(right),
            "lang": String(lang),
            "input": String(input),
            ..
          } else {
          continue
        }
        let obj2 = obj.copy()
        match obj.get("output") {
          Some(out) => obj2["output"] = Json::string(out.stringify())
          None => ()
        }
        check_case(tally, "lexer:latexembedded", desc, obj2, quiet, () => {
          let inner = @lexers.get_lexer_by_name(lang)
          let lx = @formatters.latex_embedded_lexer(left, right, inner)
          tokens_json_string(lx.get_tokens(input))
        })
      }
      _ => println("SKIP unknown kind \{kind}")
    }
  }
  let groups = tally.pass.keys().collect()
  for g in tally.fail.keys() {
    if !groups.contains(g) {
      groups.push(g)
    }
  }
  groups.sort()
  let mut total_pass = 0
  let mut total_fail = 0
  for g in groups {
    let p = tally.pass.get(g).unwrap_or(0)
    let f = tally.fail.get(g).unwrap_or(0)
    total_pass += p
    total_fail += f
    println("\{g}: pass=\{p} fail=\{f}")
  }
  println("total: pass=\{total_pass} fail=\{total_fail}")
}
