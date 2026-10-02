///|
priv enum Inst {
  Char(Int)
  Set(CharSet)
  Split(Int, Int) // try first, backtrack to second
  SplitIf(Int, Int, FirstSet) // Split, but go straight to the second when the first cannot start here
  Jmp(Int)
  Save(Int)
  Assert(AssertKind)
  Backref(Int, Int) // group, case folding mode
  // char (if set is None), set, min, max, greedy, and the characters the
  // continuation can start with (None: unknown), see `Compiler::follow_set`
  RepChar(Int, CharSet?, Int, Int, Bool, CharSet?)
  SetMark(Int) // regs[r] = pos
  IfEmpty(Int, Int) // if pos == regs[r] goto target
  Look(Bool, Bool, Int, Int) // behind, negated, width, body pc
  LookSet(Bool, Bool, CharSet) // Look whose body is one character: behind, negated, set
  Atomic(Int) // body pc
  CondRef(Int, Int) // group, pc of the "no" branch
  Match
}

///|
priv struct Compiler {
  prog : Array[Inst]
  subs : Array[(Node, Int)] // deferred sub-programs and the Inst index to patch
  mut nregs : Int
}

///|
/// Maximum number of instructions a single pattern may compile to.
const MAX_PROGRAM : Int = 200000

///|
fn Compiler::emit(self : Compiler, i : Inst) -> Int raise RegexError {
  if self.prog.length() >= MAX_PROGRAM {
    raise Syntax(pattern="", pos=0, message="pattern too large")
  }
  self.prog.push(i)
  self.prog.length() - 1
}

///|
fn Compiler::pc(self : Compiler) -> Int {
  self.prog.length()
}

///|
fn nullable(node : Node) -> Bool {
  match node {
    Empty | Assert(_) | Look(_, _, _) | Backref(_, _) => true
    Char(_) | Set(_) => false
    Seq(items) => items.iter().all(nullable)
    Alt(branches) => branches.iter().any(nullable)
    Group(_, n) | Atomic(n) => nullable(n)
    Repeat(n, min, _, _) => min == 0 || nullable(n)
    Cond(_, a, b) => nullable(a) || nullable(b)
  }
}

///|
fn Compiler::compile(self : Compiler, node : Node) -> Unit raise RegexError {
  match node {
    Empty => ()
    Char(c) => ignore(self.emit(Char(c)))
    Set(s) => ignore(self.emit(Set(s)))
    Seq(items) =>
      for it in items {
        self.compile(it)
      }
    Alt(branches) => {
      // Split(b1, next) b1 Jmp(end) next: Split(b2, next2) ...
      let jumps = []
      for i, b in branches {
        if i < branches.length() - 1 {
          let split = self.emit(Split(0, 0))
          self.compile(b)
          jumps.push(self.emit(Jmp(0)))
          self.prog[split] = split_guarded(b, split + 1, self.pc())
        } else {
          self.compile(b)
        }
      }
      let end = self.pc()
      for j in jumps {
        self.prog[j] = Jmp(end)
      }
    }
    Group(g, n) => {
      ignore(self.emit(Save(g * 2)))
      self.compile(n)
      ignore(self.emit(Save(g * 2 + 1)))
    }
    Assert(k) => ignore(self.emit(Assert(k)))
    Backref(g, ic) => ignore(self.emit(Backref(g, ic)))
    Look(Char(c), behind, neg) =>
      ignore(self.emit(LookSet(behind, neg, CharSet::from_ranges([(c, c)]))))
    Look(Set(s), behind, neg) => ignore(self.emit(LookSet(behind, neg, s)))
    Look(n, behind, neg) => {
      let width = match fixed_width(n) {
        Some(w) => w
        None => 0
      }
      let at = self.emit(Look(behind, neg, width, 0))
      self.subs.push((n, at))
    }
    Atomic(n) => {
      let at = self.emit(Atomic(0))
      self.subs.push((n, at))
    }
    Cond(g, yes, no) => {
      let cond = self.emit(CondRef(g, 0))
      self.compile(yes)
      let j = self.emit(Jmp(0))
      self.prog[cond] = CondRef(g, self.pc())
      self.compile(no)
      self.prog[j] = Jmp(self.pc())
    }
    Repeat(n, min, max, greed) =>
      if greed == Possessive {
        let at = self.emit(Atomic(0))
        self.subs.push((Repeat(n, min, max, Greedy), at))
      } else {
        self.compile_repeat(n, min, max, greed == Greedy)
      }
  }
}

///|
/// `Split(x, y)` where `x` starts the code of `first`: guarded by the
/// characters `first` can start with, unless it can match empty.
fn split_guarded(first : Node, x : Int, y : Int) -> Inst {
  let fs : FirstSet = { lo: 0, hi: 0, non_ascii: false, }
  if first_chars(first, fs) || fs.is_full() {
    Split(x, y)
  } else {
    SplitIf(x, y, fs)
  }
}

///|
fn Compiler::compile_repeat(
  self : Compiler,
  n : Node,
  min : Int,
  max : Int,
  greedy : Bool,
) -> Unit raise RegexError {
  match n {
    Char(c) => {
      ignore(self.emit(RepChar(c, None, min, max, greedy, None)))
      return
    }
    Set(s) => {
      ignore(self.emit(RepChar(0, Some(s), min, max, greedy, None)))
      return
    }
    _ => ()
  }
  if max == 0 {
    return
  }
  for _ in 0..<min {
    self.compile(n)
  }
  if max < 0 {
    let can_be_empty = nullable(n)
    let loop_start = self.emit(Split(0, 0))
    let body = self.pc()
    let reg = self.nregs
    if can_be_empty {
      self.nregs += 1
      ignore(self.emit(SetMark(reg)))
    }
    self.compile(n)
    let check = if can_be_empty { self.emit(IfEmpty(reg, 0)) } else { -1 }
    ignore(self.emit(Jmp(loop_start)))
    let exit = self.pc()
    self.prog[loop_start] = if greedy {
      split_guarded(n, body, exit)
    } else {
      Split(exit, body)
    }
    if check >= 0 {
      self.prog[check] = IfEmpty(reg, exit)
    }
  } else {
    // optional iterations; like CPython, an iteration that consumed nothing
    // ends the repetition
    let can_be_empty = nullable(n)
    let reg = self.nregs
    if can_be_empty {
      self.nregs += 1
    }
    let splits = []
    let checks = []
    for _ in min..<max {
      splits.push(self.emit(Split(0, 0)))
      if can_be_empty {
        ignore(self.emit(SetMark(reg)))
      }
      self.compile(n)
      if can_be_empty {
        checks.push(self.emit(IfEmpty(reg, 0)))
      }
    }
    let exit = self.pc()
    for s in splits {
      self.prog[s] = if greedy {
        split_guarded(n, s + 1, exit)
      } else {
        Split(exit, s + 1)
      }
    }
    for c in checks {
      self.prog[c] = IfEmpty(reg, exit)
    }
  }
}

///|
/// The characters the code at `pc` can start with, looking through
/// zero-width instructions, jumps and optional single-character repetitions,
/// if that ends at a single character test (`None` otherwise). A
/// conservative guard: code at `pc` fails at a position whose character is
/// not in the set.
fn Compiler::follow_set(self : Compiler, pc : Int) -> CharSet? {
  let mut pc = pc
  let pairs : Array[(Int, Int)] = []
  for _ in 0..<16 {
    match self.prog[pc] {
      Save(_) | Assert(_) | Look(_) | LookSet(_) | SetMark(_) => pc += 1
      Jmp(t) => pc = t
      Char(c) => {
        pairs.push((c, c))
        return Some(CharSet::from_ranges(pairs))
      }
      Set(s) => return Some(if pairs.is_empty() { s } else { union(pairs, s) })
      RepChar(c, set, min, _, _, _) => {
        match set {
          Some(s) => pairs.append(s.to_pairs())
          None => pairs.push((c, c))
        }
        if min > 0 {
          return Some(CharSet::from_ranges(pairs))
        }
        // optional: the code after it may start the match too
        pc += 1
      }
      _ => return None
    }
  }
  None
}

///|
fn union(pairs : Array[(Int, Int)], s : CharSet) -> CharSet {
  let all = pairs.copy()
  all.append(s.to_pairs())
  CharSet::from_ranges(all)
}

///|
/// Fills in the continuation guard of every `RepChar`, and guards every
/// `Split` whose first branch starts with a single character test.
fn Compiler::link_follows(self : Compiler) -> Unit {
  self.hoist_asserts()
  for i in 0..<self.prog.length() {
    match self.prog[i] {
      RepChar(c, set, min, max, greedy, None) =>
        self.prog[i] = RepChar(c, set, min, max, greedy, self.follow_set(i + 1))
      Split(x, y) =>
        if self.follow_set(x) is Some(s) {
          self.prog[i] = SplitIf(x, y, {
            lo: s.lo,
            hi: s.hi,
            non_ascii: s.has_non_ascii,
          })
        }
      _ => ()
    }
  }
}

///|
/// Moves the assertions in the zero-width prefix of the main program
/// (capture-group opens and assertions, e.g. `(^\s*)`) before the group
/// opens, so an attempt where they fail stops before saving anything. The
/// prefix is never a jump target (loops start with a `Split`), and a `Save`
/// does not move the position, so the order is unobservable.
fn Compiler::hoist_asserts(self : Compiler) -> Unit {
  let prog = self.prog
  let mut n = 0
  while n < prog.length() && prog[n] is (Save(_) | Assert(_)) {
    n += 1
  }
  let asserts = prog[:n].filter(i => i is Assert(_))
  let saves = prog[:n].filter(i => i is Save(_))
  for i, inst in asserts {
    prog[i] = inst
  }
  for i, inst in saves {
    prog[asserts.length() + i] = inst
  }
}

///|
/// Compiles deferred sub-programs (lookaround and atomic bodies), each
/// terminated by `Match`.
fn Compiler::finish(self : Compiler) -> Unit raise RegexError {
  let mut i = 0
  while i < self.subs.length() {
    let (node, at) = self.subs[i]
    let start = self.pc()
    self.compile(node)
    ignore(self.emit(Match))
    self.prog[at] = match self.prog[at] {
      Look(b, neg, w, _) => Look(b, neg, w, start)
      Atomic(_) => Atomic(start)
      other => other
    }
    i += 1
  }
}

///|
/// A conservative approximation of the characters a match can start with.
priv struct FirstSet {
  mut lo : UInt64
  mut hi : UInt64
  mut non_ascii : Bool
}

///|
/// Whether code unit `c` may start a match (`c` is never the end).
fn FirstSet::allows(self : FirstSet, c : Int) -> Bool {
  if c < 64 {
    ((self.lo >> c) & 1) != 0
  } else if c < 128 {
    ((self.hi >> (c - 64)) & 1) != 0
  } else {
    self.non_ascii
  }
}

///|
/// Whether every code unit is allowed (the set rules nothing out).
fn FirstSet::is_full(self : FirstSet) -> Bool {
  self.non_ascii &&
  self.lo == 0xFFFFFFFFFFFFFFFFUL &&
  self.hi == 0xFFFFFFFFFFFFFFFFUL
}

///|
fn FirstSet::add_char(self : FirstSet, c : Int) -> Unit {
  if c < 64 {
    self.lo = self.lo | (1UL << c)
  } else if c < 128 {
    self.hi = self.hi | (1UL << (c - 64))
  } else {
    self.non_ascii = true
  }
}

///|
fn FirstSet::add_set(self : FirstSet, s : CharSet) -> Unit {
  self.lo = self.lo | s.lo
  self.hi = self.hi | s.hi
  if s.has_non_ascii {
    self.non_ascii = true
  }
}

///|
/// Adds the possible first characters of `node` to `fs`; returns whether
/// `node` can match without consuming a character.
fn first_chars(node : Node, fs : FirstSet) -> Bool {
  match node {
    Empty | Assert(_) | Look(_, _, _) => true
    Char(c) => {
      fs.add_char(c)
      false
    }
    Set(s) => {
      fs.add_set(s)
      false
    }
    Seq(items) => {
      for it in items {
        if !first_chars(it, fs) {
          return false
        }
      }
      true
    }
    Alt(branches) => {
      let mut nul = false
      for b in branches {
        if first_chars(b, fs) {
          nul = true
        }
      }
      nul
    }
    Group(_, n) | Atomic(n) => first_chars(n, fs)
    Repeat(n, min, _, _) => first_chars(n, fs) || min == 0
    Backref(_, _) => true
    Cond(_, a, b) => {
      let x = first_chars(a, fs)
      let y = first_chars(b, fs)
      x || y
    }
  }
}
