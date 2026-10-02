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
  let main_end = c.emit(Match)
  c.finish()
  c.link_follows()
  let fs : FirstSet = { lo: 0, hi: 0, non_ascii: false, }
  let nullable = first_chars(node, fs)
  let vm : Vm = {
    prog: FixedArray::from_array(c.prog),
    text: "",
    end: 0,
    caps: FixedArray::make((ngroups + 1) * 2, -1),
    regs: FixedArray::make(c.nregs, -1),
    stack: FixedArray::make(64, 0),
    sp: 0,
    steps: 0,
    bt_pc: 0,
    bt_pos: 0,
    pattern,
    main_end,
    start: 0,
    must_advance: false,
    full: false,
    dirty: false,
  }
  { pattern, flags: final_flags, vm, ngroups, names, first: fs, nullable, }
}

///|
/// Number of capturing groups.
pub fn Regex::group_count(self : Regex) -> Int {
  self.ngroups
}

///|
/// Index of the named group `name`.
pub fn Regex::group_index(self : Regex, name : String) -> Int? {
  self.names.get(name)
}

///|
/// The named groups and their indices, ordered by index (the keys of
/// Python's `pattern.groupindex` / `match.groupdict()`).
pub fn Regex::group_names(self : Regex) -> Array[(String, Int)] {
  let out = self.names.to_array()
  out.sort_by_key(p => p.1)
  out
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
/// Python's clamping of `pos`/`endpos` arguments.
fn clamp_range(text : String, pos : Int, endpos : Int?) -> (Int, Int) {
  let n = text.length()
  let end = match endpos {
    Some(e) => if e < 0 { 0 } else if e > n { n } else { e }
    None => n
  }
  let p = if pos < 0 { 0 } else { pos }
  (p, end)
}

///|
/// Points the shared VM at `text[..end]`, charging `budget`. Every `enter`
/// is paired with `leave` (or, on an error, `abandon`).
fn Regex::enter(self : Regex, text : String, end : Int, budget : Budget) -> Vm {
  let vm = self.vm
  vm.text = text
  vm.end = end
  vm.steps = budget.remaining
  vm
}

///|
/// Returns the unused steps to `budget` and releases the input.
fn Vm::leave(self : Vm, budget : Budget) -> Unit {
  budget.remaining = self.steps
  // do not keep the input alive through the cached VM
  self.text = ""
}

///|
/// Leaves the VM clean after an error (budget exhausted).
fn Vm::abandon(self : Vm, budget : Budget) -> Unit {
  self.text = ""
  self.sp = 0
  self.dirty = true
  budget.remaining = 0
}

///|
/// One match attempt at `pos` of the text set up by `enter`. Returns the end
/// of the match or -1; on success the groups are left in the VM.
///
/// A failed attempt pops every frame it pushed, and popping restores the
/// capture and register slots, so the slots only need to be cleared after a
/// success (or an error).
fn Vm::attempt(
  self : Vm,
  pos : Int,
  must_advance~ : Bool,
  full~ : Bool,
) -> Int raise RegexError {
  if self.dirty {
    if self.caps.length() > 2 {
      self.caps.fill(-1)
    }
    if self.regs.length() > 0 {
      self.regs.fill(-1)
    }
    self.dirty = false
  }
  self.sp = 0
  self.start = pos
  self.must_advance = must_advance
  self.full = full
  let r = self.run(0, pos)
  if r >= 0 {
    self.dirty = true
  }
  r
}

///|
/// Runs one match attempt at `pos`, charging `budget`. Returns the end of
/// the match or -1; on success the groups are left in the VM.
fn Regex::exec_end(
  self : Regex,
  text : String,
  pos : Int,
  end : Int,
  budget : Budget,
  must_advance~ : Bool,
  full~ : Bool,
) -> Int raise RegexError {
  let vm = self.enter(text, end, budget)
  errdefer vm.abandon(budget)
  let r = vm.attempt(pos, must_advance~, full~)
  vm.leave(budget)
  r
}

///|
/// The `Match` for a successful attempt at `pos` ending at `r`.
fn Regex::make_match(self : Regex, text : String, pos : Int, r : Int) -> Match {
  let vm = self.vm
  let n = vm.caps.length()
  let caps = FixedArray::make(n, -1)
  if n > 2 {
    caps.unsafe_blit(2, vm.caps, 2, n - 2)
  }
  caps[0] = pos
  caps[1] = r
  { text, caps, names: self.names, }
}

///|
/// Runs one match attempt at `pos`, charging `budget`.
fn Regex::exec(
  self : Regex,
  text : String,
  pos : Int,
  end : Int,
  budget : Budget,
  must_advance~ : Bool,
  full~ : Bool,
) -> Match? raise RegexError {
  let r = self.exec_end(text, pos, end, budget, must_advance~, full~)
  if r < 0 {
    None
  } else {
    Some(self.make_match(text, pos, r))
  }
}

///|
/// Like `match_at`, but returns only the end offset of the match (or -1)
/// without allocating a `Match`: for callers that need the whole-match span
/// only. The prefilter is not applied (see `may_start_with`).
pub fn Regex::match_end(
  self : Regex,
  text : String,
  pos : Int,
  endpos? : Int,
  budget? : Budget,
) -> Int raise RegexError {
  let (pos, end) = clamp_range(text, pos, endpos)
  if pos > end {
    return -1
  }
  let budget = budget.unwrap_or(Budget::new(default_steps))
  self.exec_end(text, pos, end, budget, must_advance=false, full=false)
}

///|
/// Whether a match can start at a position whose UTF-16 code unit is `c`
/// (`-1`: the end of the input). Conservative: `true` may still fail to
/// match, `false` never matches.
pub fn Regex::may_start_with(self : Regex, c : Int) -> Bool {
  if self.nullable {
    true
  } else if c < 0 {
    false
  } else if c < 64 {
    ((self.first.lo >> c) & 1) != 0
  } else if c < 128 {
    ((self.first.hi >> (c - 64)) & 1) != 0
  } else {
    self.first.non_ascii
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
  let (pos, end) = clamp_range(text, pos, endpos)
  if pos > end || self.rejects(text, pos, end) {
    return None
  }
  let budget = budget.unwrap_or(Budget::new(default_steps))
  self.exec(text, pos, end, budget, must_advance=false, full=false)
}

///|
/// Python's `pattern.fullmatch(text, pos, endpos)`.
pub fn Regex::fullmatch(
  self : Regex,
  text : String,
  pos? : Int = 0,
  endpos? : Int,
  budget? : Budget,
) -> Match? raise RegexError {
  let (pos, end) = clamp_range(text, pos, endpos)
  if pos > end || self.rejects(text, pos, end) {
    return None
  }
  let budget = budget.unwrap_or(Budget::new(default_steps))
  self.exec(text, pos, end, budget, must_advance=false, full=true)
}

///|
/// Whether code unit `c` can start a match (see `may_start_with`).
fn Regex::can_start(self : Regex, c : Int) -> Bool {
  self.first.allows(c)
}

///|
/// Scans `text[pos..end]` for the first match, trying each code point
/// position the prefilter allows (one budget step per position ruled out).
fn Regex::search_from(
  self : Regex,
  text : String,
  pos : Int,
  end : Int,
  budget : Budget,
  must_advance : Bool,
) -> Match? raise RegexError {
  let vm = self.enter(text, end, budget)
  errdefer vm.abandon(budget)
  let nullable = self.nullable
  let mut p = pos
  while p <= end {
    if !nullable {
      // skip the positions the prefilter rules out
      let mut skipped = 0
      while p < end && !self.can_start(text.unsafe_get(p).to_int()) {
        skipped += 1
        p = next_position(text, p, end)
      }
      if p >= end {
        // a non-nullable pattern cannot match at the end
        skipped += 1
      }
      vm.steps -= skipped
      if vm.steps < 0 {
        raise BudgetExceeded(pattern=self.pattern)
      }
      if p >= end {
        break
      }
    }
    let r = vm.attempt(p, must_advance=must_advance && p == pos, full=false)
    if r >= 0 {
      vm.leave(budget)
      return Some(self.make_match(text, p, r))
    }
    p = next_position(text, p, end)
  }
  vm.leave(budget)
  None
}

///|
/// The position after the code point at `p` (`p + 1` at the end).
fn next_position(text : String, p : Int, end : Int) -> Int {
  if p + 1 < end &&
    is_high(text.unsafe_get(p).to_int()) &&
    is_low(text.unsafe_get(p + 1).to_int()) {
    p + 2
  } else {
    p + 1
  }
}

///|
/// Python's `pattern.search(text, pos, endpos)`. One budget covers the whole
/// scan.
pub fn Regex::search(
  self : Regex,
  text : String,
  pos? : Int = 0,
  endpos? : Int,
  budget? : Budget,
) -> Match? raise RegexError {
  let (pos, end) = clamp_range(text, pos, endpos)
  let budget = budget.unwrap_or(Budget::new(default_steps))
  self.search_from(text, pos, end, budget, false)
}

///|
/// All non-overlapping matches, like Python's `finditer` (an empty match may
/// be followed by a non-empty match at the same position).
pub fn Regex::find_all(
  self : Regex,
  text : String,
  budget? : Budget,
) -> Array[Match] raise RegexError {
  let budget = budget.unwrap_or(Budget::new(default_steps))
  let out = []
  let end = text.length()
  let mut p = 0
  let mut must_advance = false
  while p <= end {
    match self.search_from(text, p, end, budget, must_advance) {
      None => break
      Some(m) => {
        out.push(m)
        must_advance = m.end() == m.start()
        p = m.end()
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
