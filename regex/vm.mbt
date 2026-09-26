///|
/// Backtrack frame kinds; every frame occupies four slots of `Vm::stack`.
const BT_ALT : Int = 0

///|
const BT_CAP : Int = 1

///|
const BT_REG : Int = 2

///|
const BT_GREEDY : Int = 3

///|
const BT_LAZY : Int = 4

///|
priv struct Vm {
  prog : FixedArray[Inst]
  mut text : String
  mut end : Int
  caps : FixedArray[Int]
  regs : FixedArray[Int]
  stack : Array[Int]
  mut steps : Int
  mut bt_pc : Int
  mut bt_pos : Int
  pattern : String
}

///|
fn is_high(c : Int) -> Bool {
  c >= 0xD800 && c <= 0xDBFF
}

///|
fn is_low(c : Int) -> Bool {
  c >= 0xDC00 && c <= 0xDFFF
}

///|
/// Code point starting at `pos` (which must be `< end`).
fn Vm::cp_at(self : Vm, pos : Int) -> Int {
  let c = self.text.unsafe_get(pos).to_int()
  if is_high(c) && pos + 1 < self.end {
    let d = self.text.unsafe_get(pos + 1).to_int()
    if is_low(d) {
      return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00)
    }
  }
  c
}

///|
fn cp_width(cp : Int) -> Int {
  if cp > 0xFFFF {
    2
  } else {
    1
  }
}

///|
/// Position of the code point preceding `pos`, never going below `floor`.
fn Vm::step_back(self : Vm, pos : Int, floor : Int) -> Int {
  if pos - 2 >= floor &&
    is_low(self.text.unsafe_get(pos - 1).to_int()) &&
    is_high(self.text.unsafe_get(pos - 2).to_int()) {
    pos - 2
  } else {
    pos - 1
  }
}

///|
/// Code point ending at `pos` (which must be `> 0`).
fn Vm::cp_before(self : Vm, pos : Int) -> Int {
  let p = self.step_back(pos, 0)
  if p == pos - 2 {
    self.cp_at(p)
  } else {
    self.text.unsafe_get(pos - 1).to_int()
  }
}

///|
fn Vm::push(self : Vm, kind : Int, a : Int, b : Int, c : Int) -> Unit {
  self.stack.push(kind)
  self.stack.push(a)
  self.stack.push(b)
  self.stack.push(c)
}

///|
fn is_word_cp(c : Int, ascii : Bool) -> Bool {
  if ascii {
    ascii_word.contains(c)
  } else {
    unicode_word.contains(c)
  }
}

///|
fn Vm::check_assert(self : Vm, k : AssertKind, pos : Int) -> Bool {
  match k {
    Bol | StrStart => pos == 0
    BolM => pos == 0 || self.text.unsafe_get(pos - 1).to_int() == '\n'
    Eol =>
      pos == self.end ||
      (pos == self.end - 1 && self.text.unsafe_get(pos).to_int() == '\n')
    EolM => pos == self.end || self.text.unsafe_get(pos).to_int() == '\n'
    StrEnd => pos == self.end
    WordB(ascii) => {
      if self.end == 0 {
        return false
      }
      let before = pos > 0 && is_word_cp(self.cp_before(pos), ascii)
      let after = pos < self.end && is_word_cp(self.cp_at(pos), ascii)
      before != after
    }
    NotWordB(ascii) => {
      if self.end == 0 {
        return false
      }
      let before = pos > 0 && is_word_cp(self.cp_before(pos), ascii)
      let after = pos < self.end && is_word_cp(self.cp_at(pos), ascii)
      before == after
    }
  }
}

///|
/// Tries to match one character of a `RepChar` at `pos`; returns the new
/// position or -1.
fn Vm::one(self : Vm, c : Int, set : CharSet?, pos : Int) -> Int {
  if pos >= self.end {
    return -1
  }
  let cp = self.cp_at(pos)
  let ok = match set {
    None => cp == c
    Some(s) => s.contains(cp)
  }
  if ok {
    pos + cp_width(cp)
  } else {
    -1
  }
}

///|
fn Vm::tick(self : Vm) -> Unit raise RegexError {
  self.steps -= 1
  if self.steps < 0 {
    raise BudgetExceeded(pattern=self.pattern)
  }
}

///|
/// Pops frames down to `base` until a resumable one is found. On success the
/// resume point is stored in `bt_pc`/`bt_pos`.
fn Vm::backtrack(self : Vm, base : Int) -> Bool raise RegexError {
  let st = self.stack
  while st.length() > base {
    self.tick()
    let top = st.length() - 4
    let kind = st[top]
    let a = st[top + 1]
    let b = st[top + 2]
    let c = st[top + 3]
    if kind == BT_ALT {
      st.truncate(top)
      self.bt_pc = a
      self.bt_pos = b
      return true
    } else if kind == BT_CAP {
      self.caps[a] = b
      st.truncate(top)
    } else if kind == BT_REG {
      self.regs[a] = b
      st.truncate(top)
    } else if kind == BT_GREEDY {
      // a = pc of RepChar, b = min_pos, c = current position
      let next_char = match self.prog[a + 1] {
        Char(ch) => ch
        _ => -1
      }
      let mut p = self.step_back(c, b)
      if next_char >= 0 {
        while p > b && self.cp_at(p) != next_char {
          p = self.step_back(p, b)
        }
        if p == b && (p >= self.end || self.cp_at(p) != next_char) {
          st.truncate(top)
          continue
        }
      }
      if p <= b {
        st.truncate(top)
      } else {
        st[top + 3] = p
      }
      self.bt_pc = a + 1
      self.bt_pos = p
      return true
    } else {
      // BT_LAZY: a = pc of RepChar, b = count so far, c = position
      guard self.prog[a] is RepChar(ch, set, _, max, _) else { panic() }
      let np = self.one(ch, set, c)
      if np < 0 {
        st.truncate(top)
        continue
      }
      if max >= 0 && b + 1 >= max {
        st.truncate(top)
      } else {
        st[top + 2] = b + 1
        st[top + 3] = np
      }
      self.bt_pc = a + 1
      self.bt_pos = np
      return true
    }
  }
  false
}

///|
/// Discards alternatives above `base`, keeping the undo log (capture and
/// register restores) so outer backtracking still restores state.
fn Vm::commit(self : Vm, base : Int) -> Unit {
  let st = self.stack
  let mut w = base
  for r = base; r < st.length(); r = r + 4 {
    let kind = st[r]
    if kind == BT_CAP || kind == BT_REG {
      if w != r {
        st[w] = kind
        st[w + 1] = st[r + 1]
        st[w + 2] = st[r + 2]
        st[w + 3] = st[r + 3]
      }
      w += 4
    }
  }
  st.truncate(w)
}

///|
/// Undoes every frame above `base`.
fn Vm::unwind(self : Vm, base : Int) -> Unit {
  let st = self.stack
  while st.length() > base {
    let top = st.length() - 4
    let kind = st[top]
    if kind == BT_CAP {
      self.caps[st[top + 1]] = st[top + 2]
    } else if kind == BT_REG {
      self.regs[st[top + 1]] = st[top + 2]
    }
    st.truncate(top)
  }
}

///|
/// Runs the program from `start_pc` at `start_pos`. Returns the end position
/// of the first successful path, or -1.
fn Vm::run(self : Vm, start_pc : Int, start_pos : Int) -> Int raise RegexError {
  let base = self.stack.length()
  let prog = self.prog
  let mut pc = start_pc
  let mut pos = start_pos
  while true {
    self.tick()
    let ok = match prog[pc] {
      Char(c) =>
        if pos < self.end {
          let cp = self.cp_at(pos)
          if cp == c {
            pos += cp_width(cp)
            pc += 1
            true
          } else {
            false
          }
        } else {
          false
        }
      Set(s) =>
        if pos < self.end {
          let cp = self.cp_at(pos)
          if s.contains(cp) {
            pos += cp_width(cp)
            pc += 1
            true
          } else {
            false
          }
        } else {
          false
        }
      Split(x, y) => {
        self.push(BT_ALT, y, pos, 0)
        pc = x
        true
      }
      Jmp(x) => {
        pc = x
        true
      }
      Save(slot) => {
        self.push(BT_CAP, slot, self.caps[slot], 0)
        self.caps[slot] = pos
        pc += 1
        true
      }
      Assert(k) =>
        if self.check_assert(k, pos) {
          pc += 1
          true
        } else {
          false
        }
      Backref(g, ic) => {
        let s = self.caps[g * 2]
        let e = self.caps[g * 2 + 1]
        if s < 0 || e < 0 {
          false
        } else if ic {
          let mut p = pos
          let mut q = s
          let mut good = true
          while q < e {
            if p >= self.end {
              good = false
              break
            }
            let c1 = self.cp_at(q)
            let c2 = self.cp_at(p)
            if c1 != c2 && to_lower(c1) != to_lower(c2) {
              good = false
              break
            }
            q += cp_width(c1)
            p += cp_width(c2)
          }
          if good {
            pos = p
            pc += 1
          }
          good
        } else {
          let len = e - s
          if pos + len > self.end {
            false
          } else {
            let mut good = true
            for i in 0..<len {
              if self.text.unsafe_get(s + i) != self.text.unsafe_get(pos + i) {
                good = false
                break
              }
            }
            if good {
              pos += len
              pc += 1
            }
            good
          }
        }
      }
      RepChar(c, set, min, max, greedy) => {
        let mut p = pos
        let mut count = 0
        let mut good = true
        while count < min {
          let np = self.one(c, set, p)
          if np < 0 {
            good = false
            break
          }
          p = np
          count += 1
        }
        if good {
          if greedy {
            let min_pos = p
            while max < 0 || count < max {
              let np = self.one(c, set, p)
              if np < 0 {
                break
              }
              p = np
              count += 1
            }
            if p > min_pos {
              self.push(BT_GREEDY, pc, min_pos, p)
            }
          } else if max < 0 || count < max {
            self.push(BT_LAZY, pc, count, p)
          }
          pos = p
          pc += 1
        }
        good
      }
      SetMark(r) => {
        self.push(BT_REG, r, self.regs[r], 0)
        self.regs[r] = pos
        pc += 1
        true
      }
      IfEmpty(r, target) => {
        if pos == self.regs[r] {
          pc = target
        } else {
          pc += 1
        }
        true
      }
      Look(behind, neg, width, body) => {
        let sub_base = self.stack.length()
        let mut start = pos
        let mut possible = true
        if behind {
          for _ in 0..<width {
            if start <= 0 {
              possible = false
              break
            }
            start = self.step_back(start, 0)
          }
        }
        let matched = if possible {
          let r = self.run(body, start)
          if behind {
            r == pos
          } else {
            r >= 0
          }
        } else {
          false
        }
        if neg {
          self.unwind(sub_base)
          if matched {
            false
          } else {
            pc += 1
            true
          }
        } else if matched {
          self.commit(sub_base)
          pc += 1
          true
        } else {
          self.unwind(sub_base)
          false
        }
      }
      Atomic(body) => {
        let sub_base = self.stack.length()
        let r = self.run(body, pos)
        if r >= 0 {
          self.commit(sub_base)
          pos = r
          pc += 1
          true
        } else {
          false
        }
      }
      CondRef(g, no) => {
        if g * 2 + 1 < self.caps.length() &&
          self.caps[g * 2] >= 0 &&
          self.caps[g * 2 + 1] >= 0 {
          pc += 1
        } else {
          pc = no
        }
        true
      }
      Match => return pos
    }
    if !ok {
      if self.backtrack(base) {
        pc = self.bt_pc
        pos = self.bt_pos
      } else {
        return -1
      }
    }
  }
  -1
}
