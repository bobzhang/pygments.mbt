///|
/// A compiled regular expression with Python `re` syntax and semantics,
/// matching code points over a UTF-16 `String`. Positions are UTF-16 offsets.
pub struct Regex {
  pattern : String
  flags : Int
  priv vm : Vm
  priv ngroups : Int
  priv names : Map[String, Int]
  priv first : FirstSet
  priv nullable : Bool
}

///|
/// A step budget shared by several match calls (e.g. one lexing request).
pub struct Budget {
  mut remaining : Int
}

///|
/// Creates a budget of `steps` VM steps.
pub fn Budget::new(steps : Int) -> Budget {
  { remaining: steps, }
}

///|
/// Default number of VM steps allowed for a single match call without an
/// explicit budget.
pub let default_steps : Int = 50_000_000

///|
/// Compiles `pattern` with Python `re` flags (`IGNORECASE`, `MULTILINE`, ...).
///
/// ```mbt check
/// test {
///   let re = @regex.compile("(?P<word>\\w+)\\s*=", flags=@regex.MULTILINE)
///   guard re.match_at("  key = 1", 2) is Some(m) else { fail("no match") }
///   debug_inspect(m.group(1), content="Some(\"key\")")
///   inspect(m.end(), content="7")
/// }
/// ```
pub fn compile(pattern : String, flags? : Int = 0) -> Regex raise RegexError {
  let (node, ngroups, names, final_flags) = parse_pattern(pattern, flags)
  let c : Compiler = { prog: [], subs: [], nregs: 0, }
  c.compile(node)
  ignore(c.emit(Match))
  c.finish()
  let fs : FirstSet = { lo: 0, hi: 0, non_ascii: false, }
  let nullable = first_chars(node, fs)
  let vm : Vm = {
    prog: FixedArray::from_array(c.prog),
    text: "",
    end: 0,
    caps: FixedArray::make((ngroups + 1) * 2, -1),
    regs: FixedArray::make(c.nregs, -1),
    stack: [],
    steps: 0,
    bt_pc: 0,
    bt_pos: 0,
    pattern,
  }
  { pattern, flags: final_flags, vm, ngroups, names, first: fs, nullable, }
}

///|
/// Number of capturing groups.
pub fn Regex::group_count(self : Regex) -> Int {
  self.ngroups
}

///|
/// Index of the named group `name`, if any.
pub fn Regex::group_index(self : Regex, name : String) -> Int? {
  self.names.get(name)
}

///|
/// Whether the prefilter rules out a match starting at `pos`.
fn Regex::rejects(self : Regex, text : String, pos : Int, end : Int) -> Bool {
  if self.nullable {
    return false
  }
  if pos >= end {
    return true
  }
  let c = text.unsafe_get(pos).to_int()
  if c < 64 {
    ((self.first.lo >> c) & 1) == 0
  } else if c < 128 {
    ((self.first.hi >> (c - 64)) & 1) == 0
  } else {
    !self.first.non_ascii
  }
}

///|
fn Regex::exec(
  self : Regex,
  text : String,
  pos : Int,
  end : Int,
  budget : Budget?,
) -> Match? raise RegexError {
  let vm = self.vm
  vm.text = text
  vm.end = end
  vm.caps.fill(-1)
  vm.regs.fill(-1)
  vm.stack.clear()
  vm.steps = match budget {
    Some(b) => b.remaining
    None => default_steps
  }
  errdefer {
    // leave the shared VM clean before propagating
    vm.text = ""
    vm.stack.clear()
    match budget {
      Some(b) => b.remaining = 0
      None => ()
    }
  }
  let r = vm.run(0, pos)
  match budget {
    Some(b) => b.remaining = vm.steps
    None => ()
  }
  vm.text = ""
  vm.stack.clear()
  if r < 0 {
    None
  } else {
    let caps = FixedArray::make(vm.caps.length(), -1)
    for i in 2..<caps.length() {
      caps[i] = vm.caps[i]
    }
    caps[0] = pos
    caps[1] = r
    Some({ text, caps, names: self.names, })
  }
}

///|
/// Python's `pattern.match(text, pos, endpos)`: matches only at `pos`.
pub fn Regex::match_at(
  self : Regex,
  text : String,
  pos : Int,
  endpos? : Int,
  budget? : Budget,
) -> Match? raise RegexError {
  let end = match endpos {
    Some(e) => if e < text.length() { e } else { text.length() }
    None => text.length()
  }
  if pos > end || self.rejects(text, pos, end) {
    return None
  }
  self.exec(text, pos, end, budget)
}

///|
/// Python's `pattern.fullmatch(text)`.
pub fn Regex::fullmatch(
  self : Regex,
  text : String,
  budget? : Budget,
) -> Match? raise RegexError {
  match self.match_at(text, 0, budget?) {
    Some(m) if m.end() == text.length() => Some(m)
    Some(_) =>
      // retry with an explicit anchor to respect backtracking semantics
      compile("(?:" + self.pattern + ")\\Z", flags=self.flags).match_at(
        text,
        0,
        budget?,
      )
    None => None
  }
}

///|
/// Python's `pattern.search(text, pos, endpos)`.
pub fn Regex::search(
  self : Regex,
  text : String,
  pos? : Int = 0,
  endpos? : Int,
  budget? : Budget,
) -> Match? raise RegexError {
  let end = match endpos {
    Some(e) => if e < text.length() { e } else { text.length() }
    None => text.length()
  }
  let mut p = pos
  while p <= end {
    if !self.rejects(text, p, end) {
      match self.exec(text, p, end, budget) {
        Some(m) => return Some(m)
        None => ()
      }
    }
    if p < end &&
      is_high(text.unsafe_get(p).to_int()) &&
      p + 1 < end &&
      is_low(text.unsafe_get(p + 1).to_int()) {
      p += 2
    } else {
      p += 1
    }
  }
  None
}

///|
/// All non-overlapping matches, like Python's `finditer`.
pub fn Regex::find_all(
  self : Regex,
  text : String,
  budget? : Budget,
) -> Array[Match] raise RegexError {
  let out = []
  let mut p = 0
  let mut last_empty_at = -1
  while p <= text.length() {
    match self.search(text, pos=p, budget?) {
      None => break
      Some(m) => {
        if m.start() == m.end() && m.start() == last_empty_at {
          p = m.start() + 1
          continue
        }
        out.push(m)
        if m.start() == m.end() {
          last_empty_at = m.end()
          p = m.end()
          // an empty match: the next match must start later or be non-empty
          match self.match_at(text, p, budget?) {
            Some(m2) if m2.end() > p => {
              out.push(m2)
              p = m2.end()
              last_empty_at = -1
            }
            _ => p = p + 1
          }
        } else {
          p = m.end()
          last_empty_at = -1
        }
      }
    }
  }
  out
}

///|
/// Replaces every match with the result of `f` (Python's `sub` with a
/// function).
pub fn Regex::replace_all(
  self : Regex,
  text : String,
  f : (Match) -> String,
  budget? : Budget,
) -> String raise RegexError {
  let sb = StringBuilder()
  let mut last = 0
  for m in self.find_all(text, budget?) {
    sb.write_string(text.unsafe_substring(start=last, end=m.start()))
    sb.write_string(f(m))
    last = m.end()
  }
  sb.write_string(text.unsafe_substring(start=last, end=text.length()))
  sb.to_string()
}

///|
/// Python's `pattern.split(text)` (captured groups are included).
pub fn Regex::split(
  self : Regex,
  text : String,
  budget? : Budget,
) -> Array[String?] raise RegexError {
  let out : Array[String?] = []
  let mut last = 0
  for m in self.find_all(text, budget?) {
    out.push(Some(text.unsafe_substring(start=last, end=m.start())))
    for g in 1..<=self.ngroups {
      out.push(m.group(g))
    }
    last = m.end()
  }
  out.push(Some(text.unsafe_substring(start=last, end=text.length())))
  out
}

///|
/// The result of a successful match.
pub struct Match {
  text : String
  priv caps : FixedArray[Int]
  priv names : Map[String, Int]
}

///|
/// Start offset of group `g` (default 0), or -1 if it did not participate.
pub fn Match::start(self : Match, group? : Int = 0) -> Int {
  self.caps[group * 2]
}

///|
/// End offset of group `g` (default 0), or -1 if it did not participate.
pub fn Match::end(self : Match, group? : Int = 0) -> Int {
  self.caps[group * 2 + 1]
}

///|
/// Number of capturing groups of the pattern.
pub fn Match::group_count(self : Match) -> Int {
  self.caps.length() / 2 - 1
}

///|
/// Text of group `g`, or `None` if it did not participate.
pub fn Match::group(self : Match, g : Int) -> String? {
  let s = self.caps[g * 2]
  let e = self.caps[g * 2 + 1]
  if s < 0 || e < 0 {
    None
  } else {
    Some(self.text.unsafe_substring(start=s, end=e))
  }
}

///|
/// Text of the whole match.
pub fn Match::matched(self : Match) -> String {
  self.text.unsafe_substring(start=self.caps[0], end=self.caps[1])
}

///|
/// Text of the named group `name`, if it exists and participated.
pub fn Match::named(self : Match, name : String) -> String? {
  match self.names.get(name) {
    Some(g) => self.group(g)
    None => None
  }
}

///|
/// Index of the named group `name`.
pub fn Match::name_index(self : Match, name : String) -> Int? {
  self.names.get(name)
}

///|
/// A match object covering `text[start:end]` with no groups (Python's
/// `_PseudoMatch`, used when a callback is applied to a sub-group).
pub fn Match::from_span(text : String, start : Int, end : Int) -> Match {
  { text, caps: [start, end], names: {}, }
}
