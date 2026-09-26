///|
/// Raised when no lexer matches a lookup.
pub suberror ClassNotFound {
  ClassNotFound(String)
} derive(Debug)

///|
/// Python's `find_lexer_class_by_name`: the lexer class with `alias`.
pub fn find_lexer_class_by_name(
  lexer_alias : String,
) -> (@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise) raise ClassNotFound {
  let a = lexer_alias.to_lower()
  if a != "" {
    for entry in all_lexers {
      if entry.0.aliases.contains(a) {
        return entry
      }
    }
  }
  raise ClassNotFound("no lexer for alias \{@pystr.repr(lexer_alias)} found")
}

///|
/// Python's `get_lexer_by_name`.
///
/// ```mbt check
/// test {
///   let lx = @lexers.get_lexer_by_name("py")
///   inspect(lx.name(), content="Python")
/// }
/// ```
pub fn get_lexer_by_name(
  lexer_alias : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  (find_lexer_class_by_name(lexer_alias).1)(options)
}

///|
/// Python's `find_lexer_class`: the lexer class whose display name is `name`.
pub fn find_lexer_class(
  name : String,
) -> (@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise)? {
  for entry in all_lexers {
    if entry.0.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// The last path component of `path` (Python's `os.path.basename`).
pub fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path.unsafe_substring(start=i + 1, end=path.length())
    None => path
  }
}

///|
/// Python's `fnmatch.fnmatchcase` (as used by `_fn_matches`).
pub fn fn_matches(name : String, pattern : String) -> Bool {
  let n = name.to_array()
  let p = pattern.to_array()
  fn go(i : Int, j : Int) -> Bool {
    if j == p.length() {
      return i == n.length()
    }
    match p[j] {
      '*' => {
        for k = i; k <= n.length(); k = k + 1 {
          if go(k, j + 1) {
            return true
          }
        }
        false
      }
      '?' => i < n.length() && go(i + 1, j + 1)
      '[' =>
        match parse_bracket(p, j) {
          None => i < n.length() && n[i] == '[' && go(i + 1, j + 1)
          Some((negate, items, next)) => {
            if i >= n.length() {
              return false
            }
            let c = n[i]
            let mut hit = false
            for it in items {
              if c >= it.0 && c <= it.1 {
                hit = true
              }
            }
            hit != negate && go(i + 1, next)
          }
        }
      ch => i < n.length() && n[i] == ch && go(i + 1, j + 1)
    }
  }

  go(0, 0)
}

///|
/// Parses a glob bracket expression starting at `p[j] == '['`.
fn parse_bracket(p : Array[Char], j : Int) -> (Bool, Array[(Char, Char)], Int)? {
  let mut k = j + 1
  let negate = k < p.length() && p[k] == '!'
  if negate {
    k += 1
  }
  let items = []
  let start = k
  while k < p.length() && (p[k] != ']' || k == start) {
    if k + 2 < p.length() && p[k + 1] == '-' && p[k + 2] != ']' {
      items.push((p[k], p[k + 2]))
      k += 3
    } else {
      items.push((p[k], p[k]))
      k += 1
    }
  }
  if k >= p.length() {
    None
  } else {
    Some((negate, items, k + 1))
  }
}

///|
fn analyse(info : @lexer.LexerInfo, text : String) -> Double {
  @lexer.clamp_score((info.analyse_text)(text))
}

///|
/// Python's `find_lexer_class_for_filename`.
pub fn find_lexer_class_for_filename(
  filename : String,
  code? : String,
) -> (@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise)? {
  let fname = basename(filename)
  let matches = []
  for entry in all_lexers {
    for pat in entry.0.filenames {
      if fn_matches(fname, pat) {
        matches.push((entry, pat))
      }
    }
  }
  let rating = (
    m : ((@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise), String),
  ) => {
    let bonus = if m.1.contains("*") { 0.0 } else { 0.5 }
    let score = match code {
      Some(c) if c != "" => analyse(m.0.0, c)
      _ => m.0.0.priority
    }
    (score + bonus, m.0.0.class_name)
  }
  let mut best = None
  for m in matches {
    let r = rating(m)
    match best {
      None => best = Some((r, m.0))
      Some((br, _)) =>
        if r.0 > br.0 || (r.0 == br.0 && r.1 >= br.1) {
          best = Some((r, m.0))
        }
    }
  }
  best.map(b => b.1)
}

///|
/// Python's `get_lexer_for_filename`.
pub fn get_lexer_for_filename(
  filename : String,
  code? : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  match find_lexer_class_for_filename(filename, code?) {
    Some(entry) => (entry.1)(options)
    None =>
      raise ClassNotFound(
        "no lexer for filename \{@pystr.repr(filename)} found",
      )
  }
}

///|
/// Python's `get_lexer_for_mimetype`.
pub fn get_lexer_for_mimetype(
  mime : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  for entry in all_lexers {
    if entry.0.mimetypes.contains(mime) {
      return (entry.1)(options)
    }
  }
  raise ClassNotFound("no lexer for mimetype \{@pystr.repr(mime)} found")
}

///|
/// Python's `guess_lexer`: vim modeline first, then the best `analyse_text`.
pub fn guess_lexer(
  text : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  match get_filetype_from_buffer(text) {
    Some(ft) =>
      try {
        return get_lexer_by_name(ft, options~)
      } catch {
        ClassNotFound(_) => ()
        e => raise e
      }
    None => ()
  }
  let mut best = 0.0
  let mut best_entry = None
  for entry in all_lexers {
    let rv = analyse(entry.0, text)
    if rv == 1.0 {
      return (entry.1)(options)
    }
    if rv > best {
      best = rv
      best_entry = Some(entry)
    }
  }
  match best_entry {
    Some(e) if best > 0.0 => (e.1)(options)
    _ => raise ClassNotFound("no lexer matching the text found")
  }
}

///|
/// Python's `guess_lexer_for_filename`.
pub fn guess_lexer_for_filename(
  filename : String,
  text : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  let fname = basename(filename)
  let primary : Map[String, Bool] = Map([])
  let matching = []
  for entry in all_lexers {
    let mut found = false
    for pat in entry.0.filenames {
      if fn_matches(fname, pat) {
        found = true
        primary[entry.0.class_name] = true
      }
    }
    for pat in entry.0.alias_filenames {
      if fn_matches(fname, pat) {
        found = true
        primary[entry.0.class_name] = false
      }
    }
    if found {
      matching.push(entry)
    }
  }
  if matching.is_empty() {
    raise ClassNotFound("no lexer for filename \{@pystr.repr(fname)} found")
  }
  if matching.length() == 1 {
    return (matching[0].1)(options)
  }
  let result = []
  for entry in matching {
    let rv = analyse(entry.0, text)
    if rv == 1.0 {
      return (entry.1)(options)
    }
    result.push((rv, entry))
  }
  let key = (
    x : (Double, (@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise)),
  ) => {
    (
      x.0,
      primary.get(x.1.0.class_name).unwrap_or(false),
      x.1.0.priority,
      x.1.0.class_name,
    )
  }
  let mut best = result[0]
  for x in result {
    let a = key(x)
    let b = key(best)
    if a.0 > b.0 ||
      (
        a.0 == b.0 &&
        (
          (a.1 && !b.1) ||
          (a.1 == b.1 && (a.2 > b.2 || (a.2 == b.2 && a.3 >= b.3)))
        )
      ) {
      best = x
    }
  }
  (best.1.1)(options)
}

///|
let modeline_re : @regex.Regex = @lexer.re(
  (
    #|
    #|    (?: vi | vim | ex ) (?: [<=>]? \d* )? :
    #|    .* (?: ft | filetype | syn | syntax ) = ( [^:\s]+ )
    #|
  ),
  flags=@regex.VERBOSE,
)

///|
fn get_filetype_from_line(line : String) -> String? {
  match (modeline_re.search(line) catch { _ => None }) {
    Some(m) => m.group(1)
    None => None
  }
}

///|
/// Python's `str.splitlines()` (the line-break characters it recognises).
pub fn splitlines(s : String) -> Array[String] {
  let out = []
  let mut start = 0
  let mut i = 0
  let n = s.length()
  while i < n {
    let c = s.unsafe_get(i).to_int()
    let is_break = c == 10 ||
      c == 13 ||
      c == 11 ||
      c == 12 ||
      c == 0x1c ||
      c == 0x1d ||
      c == 0x1e ||
      c == 0x85 ||
      c == 0x2028 ||
      c == 0x2029
    if is_break {
      out.push(s.unsafe_substring(start~, end=i))
      if c == 13 && i + 1 < n && s.unsafe_get(i + 1).to_int() == 10 {
        i += 1
      }
      start = i + 1
    }
    i += 1
  }
  if start < n {
    out.push(s.unsafe_substring(start~, end=n))
  }
  out
}

///|
/// Python's `get_filetype_from_buffer`: the filetype from a vim modeline in
/// the last or first five lines.
pub fn get_filetype_from_buffer(buf : String, max_lines? : Int = 5) -> String? {
  let lines = splitlines(buf)
  let n = lines.length()
  for k in 0..<max_lines {
    let i = n - 1 - k
    if i < 0 {
      break
    }
    match get_filetype_from_line(lines[i]) {
      Some(ft) => return Some(ft)
      None => ()
    }
  }
  for i = max_lines; i >= 0; i = i - 1 {
    if i < n {
      match get_filetype_from_line(lines[i]) {
        Some(ft) => return Some(ft)
        None => ()
      }
    }
  }
  None
}
