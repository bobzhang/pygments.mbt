///|
/// Compiles a pattern known to be valid (aborts otherwise).
pub fn re(pattern : String, flags? : Int = 0) -> @regex.Regex {
  @regex.compile(pattern, flags~) catch {
    e => abort("invalid builtin regex \{pattern.escape()}: \{Repr(e)}")
  }
}

///|
/// Python's `bool(re.search(pattern, text, flags))`, for `analyse_text`.
pub fn search(pattern : @regex.Regex, text : String) -> Bool {
  (pattern.search(text) catch { _ => None }) is Some(_)
}

///|
/// Python's `bool(re.match(pattern, text))`.
pub fn matches(pattern : @regex.Regex, text : String) -> Bool {
  (pattern.match_at(text, 0) catch { _ => None }) is Some(_)
}

///|
let split_path_re : @regex.Regex = re("[/\\\\ ]")

///|
let doctype_lookup_re : @regex.Regex = re(
  (
    #|
    #|    <!DOCTYPE\s+(
    #|     [a-zA-Z_][a-zA-Z0-9]*
    #|     (?: \s+      # optional in HTML5
    #|     [a-zA-Z_][a-zA-Z0-9]*\s+
    #|     "[^"]*")?
    #|     )
    #|     [^>]*>
  ),
  flags=@regex.DOTALL | @regex.MULTILINE | @regex.VERBOSE,
)

///|
let tag_re : @regex.Regex = re(
  "<([a-zA-Z][a-zA-Z0-9._:-]*)(\\s[^>]*)?>.*?</\\1\\s*>",
  flags=@regex.IGNORECASE | @regex.DOTALL | @regex.MULTILINE,
)

///|
let xml_decl_re : @regex.Regex = re(
  "\\s*<\\?xml[^>]*\\?>",
  flags=@regex.IGNORECASE,
)

///|
/// Python's `shebang_matches`: whether the last component of the shebang
/// line (ignoring `-flags`) fully matches `regex` (case-insensitively).
pub fn shebang_matches(text : String, regex : String) -> Bool {
  let first_line = match text.find("\n") {
    Some(i) => text.unsafe_substring(start=0, end=i).to_lower()
    None => text.to_lower()
  }
  if !first_line.has_prefix("#!") {
    return false
  }
  let rest = first_line.unsafe_substring(start=2, end=first_line.length())
  let parts = (split_path_re.split(rest.trim().to_owned()) catch { _ => [] })
    .filter_map(x => x)
    .filter(x => x != "" && !x.has_prefix("-"))
  guard parts.last() is Some(found) else { return false }
  let full = re(
    "^" + regex + "(\\.(exe|cmd|bat|bin))?$",
    flags=@regex.IGNORECASE,
  )
  search(full, found)
}

///|
/// Python's `doctype_matches`.
pub fn doctype_matches(text : String, regex : String) -> Bool {
  match (doctype_lookup_re.search(text) catch { _ => None }) {
    None => false
    Some(m) => {
      let doctype = m.group(1).unwrap_or("").trim().to_owned()
      matches(re(regex, flags=@regex.IGNORECASE), doctype)
    }
  }
}

///|
/// Python's `html_doctype_matches`.
pub fn html_doctype_matches(text : String) -> Bool {
  doctype_matches(text, "html")
}

///|
/// Python's `looks_like_xml`.
pub fn looks_like_xml(text : String) -> Bool {
  if matches(xml_decl_re, text) {
    return true
  }
  if search(doctype_lookup_re, text) {
    return true
  }
  let head = if text.length() > 1000 {
    text.unsafe_substring(start=0, end=1000)
  } else {
    text
  }
  search(tag_re, head)
}

///|
/// Python's `make_analysator` wrapper: clamps to `[0, 1]`.
pub fn clamp_score(x : Double) -> Double {
  if x.is_nan() || x <= 0.0 {
    0.0
  } else if x >= 1.0 {
    1.0
  } else {
    x
  }
}
