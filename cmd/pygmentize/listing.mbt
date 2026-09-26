///|
let version_line : String = "Pygments version \{@pygments.version}, (c) 2006-present by Georg Brandl, Matthäus Chajdas and contributors."

///|
/// Python's `docstring_headline`: the first paragraph of a docstring,
/// joined into one line.
fn docstring_headline(doc : String) -> String {
  let res = []
  for line in doc.trim().split("\n") {
    let l = line.trim()
    if l.length() == 0 {
      break
    }
    res.push(l.to_owned())
  }
  res.join(" ").trim().to_owned()
}

///|
/// Python's `str` ordering: lexicographic by code point.
fn py_compare(a : String, b : String) -> Int {
  let xs = a.to_array()
  let ys = b.to_array()
  for i in 0..<@cmp.minimum(xs.length(), ys.length()) {
    if xs[i] != ys[i] {
      return xs[i].to_int() - ys[i].to_int()
    }
  }
  xs.length() - ys.length()
}

///|
/// Sort key comparison on tuples of strings (Python tuple ordering).
fn compare_rows(
  a : (String, String, String),
  b : (String, String, String),
) -> Int {
  let c = py_compare(a.0, b.0)
  if c != 0 {
    return c
  }
  let c = py_compare(a.1, b.1)
  if c != 0 {
    return c
  }
  py_compare(a.2, b.2)
}

///|
/// Python's `_print_list(what)`.
fn list_what(what : String) -> String {
  let sb = StringBuilder()
  match what {
    "lexer" => {
      sb.write_string("\nLexers:\n~~~~~~~\n")
      let rows = @lexers.all_lexers.map(e => {
        let info = e.0
        (
          info.aliases.join(", ") + ":",
          info.name,
          if info.filenames.is_empty() {
            ""
          } else {
            "(filenames " + info.filenames.join(", ") + ")"
          },
        )
      })
      rows.sort_by(compare_rows)
      for r in rows {
        sb.write_string("* \{r.0}\n    \{r.1} \{r.2}\n")
      }
    }
    "formatter" => {
      sb.write_string("\nFormatters:\n~~~~~~~~~~~\n")
      let rows = @formatters.get_all_formatters().map(f => {
        (
          f.aliases.join(", ") + ":",
          docstring_headline(f.description),
          if f.filenames.is_empty() {
            ""
          } else {
            "(filenames " + f.filenames.join(", ") + ")"
          },
        )
      })
      rows.sort_by(compare_rows)
      for r in rows {
        sb.write_string("* \{r.0}\n    \{r.1} \{r.2}\n")
      }
    }
    "filter" => {
      sb.write_string("\nFilters:\n~~~~~~~~\n")
      for name in @filters.get_all_filters() {
        let doc = filter_docs.get(name).unwrap_or("")
        sb.write_string("* \{name}:\n    \{docstring_headline(doc)}\n")
      }
    }
    _ => {
      sb.write_string("\nStyles:\n~~~~~~~\n")
      for name in @styles.get_all_styles() {
        let doc = style_docs.get(name).unwrap_or("")
        sb.write_string("* \{name}:\n    \{docstring_headline(doc)}\n")
      }
    }
  }
  sb.to_string()
}

///|
fn json_strings(xs : Array[String]) -> Json {
  Json::array(xs.map(x => Json::string(x)))
}

///|
/// Python's `_print_list_as_json(requested_items)`.
fn list_as_json(kinds : Array[String]) -> String {
  let result : Map[String, Json] = Map([])
  if kinds.contains("lexer") {
    let info : Map[String, Json] = Map([])
    for e in @lexers.all_lexers {
      info[e.0.name] = Json::object(
        Map::from_array([
          ("aliases", json_strings(e.0.aliases)),
          ("filenames", json_strings(e.0.filenames)),
          ("mimetypes", json_strings(e.0.mimetypes)),
        ]),
      )
    }
    result["lexers"] = Json::object(info)
  }
  if kinds.contains("formatter") {
    let info : Map[String, Json] = Map([])
    for f in @formatters.get_all_formatters() {
      info[f.name] = Json::object(
        Map::from_array([
          ("aliases", json_strings(f.aliases)),
          ("filenames", json_strings(f.filenames)),
          ("doc", Json::string(docstring_headline(f.description))),
        ]),
      )
    }
    result["formatters"] = Json::object(info)
  }
  if kinds.contains("filter") {
    let info : Map[String, Json] = Map([])
    for name in @filters.get_all_filters() {
      let doc = filter_docs.get(name).unwrap_or("")
      info[name] = Json::object(
        Map::from_array([("doc", Json::string(docstring_headline(doc)))]),
      )
    }
    result["filters"] = Json::object(info)
  }
  if kinds.contains("style") {
    let info : Map[String, Json] = Map([])
    for name in @styles.get_all_styles() {
      let doc = style_docs.get(name).unwrap_or("")
      info[name] = Json::object(
        Map::from_array([("doc", Json::string(docstring_headline(doc)))]),
      )
    }
    result["styles"] = Json::object(info)
  }
  py_json(Json::object(result))
}

///|
/// Python's `json.dumps` with default settings (`", "`/`": "` separators,
/// ASCII-only output).
fn py_json(j : Json) -> String {
  let sb = StringBuilder()
  fn go(j : Json) -> Unit {
    match j {
      Object(m) => {
        sb.write_char('{')
        let mut first = true
        for k, v in m {
          if !first {
            sb.write_string(", ")
          }
          first = false
          go(Json::string(k))
          sb.write_string(": ")
          go(v)
        }
        sb.write_char('}')
      }
      Array(xs) => {
        sb.write_char('[')
        for i, x in xs {
          if i > 0 {
            sb.write_string(", ")
          }
          go(x)
        }
        sb.write_char(']')
      }
      String(s) => {
        sb.write_char('"')
        for i in 0..<s.length() {
          let c = s.unsafe_get(i).to_int()
          match c {
            '"' => sb.write_string("\\\"")
            '\\' => sb.write_string("\\\\")
            '\n' => sb.write_string("\\n")
            '\r' => sb.write_string("\\r")
            '\t' => sb.write_string("\\t")
            0x08 => sb.write_string("\\b")
            0x0c => sb.write_string("\\f")
            _ =>
              if c < 0x20 || c > 0x7e {
                let hex = c.to_string(radix=16)
                sb.write_string(
                  "\\u" +
                  "0000".unsafe_substring(start=0, end=4 - hex.length()) +
                  hex,
                )
              } else {
                sb.write_char(c.unsafe_to_char())
              }
          }
        }
        sb.write_char('"')
      }
      _ => sb.write_string(j.stringify())
    }
  }

  go(j)
  sb.to_string()
}

///|
/// Python's `_print_help(what, name)`; `None` if not found.
fn help_on(what : String, name : String) -> String? {
  match what {
    "lexer" =>
      try @lexers.find_lexer_class_by_name(name) catch {
        _ => None
      } noraise {
        entry => Some("Help on the \{entry.0.name} lexer:\n\{entry.0.doc}\n")
      }
    "formatter" =>
      match @formatters.find_formatter_class(name) {
        Some((f, _)) =>
          Some(
            "Help on the \{f.name} formatter:\n\{formatter_docs.get(f.name).unwrap_or("")}\n",
          )
        None => None
      }
    _ =>
      match filter_docs.get(name) {
        Some(doc) => Some("Help on the \{name} filter:\n\{doc}\n")
        None => None
      }
  }
}
