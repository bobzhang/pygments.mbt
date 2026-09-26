///|
/// A token stream decoded from `[[ttype, value], ...]`.
fn decode_tokens(json : Json) -> Array[(@token.TokenType, String)] {
  guard json is Array(items) else { return [] }
  items.map(t => {
    guard t is Array([String(ty), String(v)]) else {
      (@token.error, "<bad token>")
    }
    (@token.from_string(ty), v)
  })
}

///|
/// String options decoded from a JSON object.
fn decode_options(json : Json?) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  if json is Some(Object(m)) {
    for k, v in m {
      if v is String(s) {
        out[k] = s
      }
    }
  }
  out
}

///|
fn opt_json(s : String?) -> Json {
  match s {
    Some(v) => Json::string(v)
    None => Json::null()
  }
}

///|
/// Python's `style_for_token` dictionary as JSON.
fn token_style_json(d : @styles.TokenStyle) -> Json {
  let true_or_null = (b : Bool) => {
    if b {
      Json::boolean(true)
    } else {
      Json::null()
    }
  }
  Json::object(
    Map([
      ("color", opt_json(d.color)),
      ("bold", Json::boolean(d.bold)),
      ("italic", Json::boolean(d.italic)),
      ("underline", Json::boolean(d.underline)),
      ("bgcolor", opt_json(d.bgcolor)),
      ("border", opt_json(d.border)),
      ("roman", true_or_null(d.roman)),
      ("sans", true_or_null(d.sans)),
      ("mono", true_or_null(d.mono)),
      ("ansicolor", opt_json(d.ansicolor)),
      ("bgansicolor", opt_json(d.bgansicolor)),
    ]),
  )
}

///|
/// The attributes of a style as the corpus records them.
fn style_attrs_json(st : @styles.Style) -> Json {
  Json::object(
    Map([
      ("name", Json::string(st.name)),
      ("background_color", opt_json(st.background_color)),
      ("highlight_color", opt_json(st.highlight_color)),
      ("line_number_color", Json::string(st.line_number_color)),
      (
        "line_number_background_color",
        Json::string(st.line_number_background_color),
      ),
      ("line_number_special_color", Json::string(st.line_number_special_color)),
      (
        "line_number_special_background_color",
        Json::string(st.line_number_special_background_color),
      ),
      ("web_style_gallery_exclude", Json::boolean(st.web_style_gallery_exclude)),
      ("aliases", Json::array(st.aliases.map(Json::string))),
    ]),
  )
}

///|
/// Index of the first difference between `a` and `b`.
fn first_diff(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a.unsafe_get(i) != b.unsafe_get(i) {
      return i
    }
  }
  n
}

///|
/// Up to 60 code units of `s` around `i`, escaped.
fn excerpt(s : String, i : Int) -> String {
  let start = if i > 30 { i - 30 } else { 0 }
  let end = if i + 30 < s.length() { i + 30 } else { s.length() }
  s.unsafe_substring(start~, end~).escape()
}
