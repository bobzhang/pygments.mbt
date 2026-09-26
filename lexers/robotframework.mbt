// Hand-written parts of pygments/lexers/robotframework.py: the whole
// `RobotFrameworkLexer` (a hand-written row/cell tokenizer).

///|
let rf_heading : @token.TokenType = @token.generic_heading

///|
let rf_setting : @token.TokenType = @token.keyword_namespace

///|
let rf_import : @token.TokenType = @token.name_namespace

///|
let rf_tc_kw_name : @token.TokenType = @token.generic_subheading

///|
let rf_keyword : @token.TokenType = @token.name_function

///|
let rf_argument : @token.TokenType = @token.string

///|
let rf_variable : @token.TokenType = @token.name_variable

///|
let rf_comment : @token.TokenType = @token.comment

///|
let rf_separator : @token.TokenType = @token.punctuation

///|
let rf_syntax : @token.TokenType = @token.punctuation

///|
let rf_gherkin : @token.TokenType = @token.generic_emph

///|
let rf_error : @token.TokenType = @token.error

///|
/// `normalize(string, remove='')`.
fn rf_normalize(s : String, remove? : String = "") -> String {
  let drop = remove + " "
  let sb = StringBuilder()
  for c in s.to_lower() {
    if !drop.contains_char(c) {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// `str(chars[a:b])` with Python slice clamping.
fn rf_join(chars : Array[Char], a : Int, b : Int) -> String {
  let n = chars.length()
  let a = if a < 0 { 0 } else if a > n { n } else { a }
  let b = if b < 0 { n + b } else if b > n { n } else { b }
  if a >= b {
    ""
  } else {
    String::from_array(chars[a:b])
  }
}

///|
/// Result of Robot Framework's `VariableSplitter` (code point indices).
priv struct RfVar {
  identifier : String
  base : String
  index : String?
  start : Int
  end : Int
}

///|
priv suberror RfNoVariable

///|
fn rf_is_escaped(s : Array[Char], index : Int) -> Bool {
  let mut escaped = false
  let mut index = index
  while index > 0 && s[index - 1] == '\\' {
    index -= 1
    escaped = !escaped
  }
  escaped
}

///|
/// `string.find(ch, start, end)` on code points.
fn rf_find(s : Array[Char], ch : Char, start : Int, end : Int) -> Int {
  let n = s.length()
  let end = if end > n { n } else { end }
  let mut i = if start < 0 { 0 } else { start }
  while i < end {
    if s[i] == ch {
      return i
    }
    i += 1
  }
  -1
}

///|
fn rf_find_start_index(
  s : Array[Char],
  identifiers : String,
  start : Int,
  end : Int,
) -> Int {
  let index = rf_find(s, '{', start, end) - 1
  if index < 0 {
    return -1
  }
  if identifiers.contains_char(s[index]) && !rf_is_escaped(s, index) {
    return index
  }
  rf_find_start_index(s, identifiers, index + 2, end)
}

///|
/// `VariableSplitter._find_variable` (on the prefix `s[:len]`).
fn rf_find_variable(
  s : Array[Char],
  len : Int,
  identifiers : String,
) -> (Int, Int) raise RfNoVariable {
  let mut max_end_index = -1
  for i = len - 1; i >= 0; i = i - 1 {
    if s[i] == '}' {
      max_end_index = i
      break
    }
  }
  if max_end_index == -1 {
    raise RfNoVariable
  }
  if rf_is_escaped(s, max_end_index) {
    return rf_find_variable(s, max_end_index, identifiers)
  }
  let start_index = rf_find_start_index(s, identifiers, 1, max_end_index)
  if start_index == -1 {
    raise RfNoVariable
  }
  (start_index, max_end_index)
}

///|
priv enum RfVarState {
  Variable
  InternalVariableStart
  WaitingListVariableIndex
  ListVariableIndex
}

///|
/// `VariableSplitter(string, identifiers)`; `None` when no variable is found
/// (`start == -1` in Python).
fn rf_split_variable(string : String, identifiers : String) -> RfVar? {
  let s = string.to_array()
  let (start, max_index) = rf_find_variable(s, s.length(), identifiers) catch {
    _ => return None
  }
  let variable_chars = [s[start], '{']
  let oc = Ref(1)
  let st = Ref(RfVarState::Variable)
  let index_chars : Array[Char] = []
  let is_list_or_dict = variable_chars[0] == '@' || variable_chars[0] == '&'
  // returns true on StopIteration
  fn variable_state(
    c : Char,
    index : Int,
    open_curly : Ref[Int],
    state : Ref[RfVarState],
  ) -> Bool {
    variable_chars.push(c)
    if c == '}' && !rf_is_escaped(s, index) {
      open_curly.val -= 1
      if open_curly.val == 0 {
        if !is_list_or_dict {
          return true
        }
        state.val = WaitingListVariableIndex
      }
    } else if identifiers.contains_char(c) {
      state.val = InternalVariableStart
    }
    false
  }
  for index = start + 2; index < s.length(); index = index + 1 {
    let c = s[index]
    let stop = match st.val {
      Variable => variable_state(c, index, oc, st)
      InternalVariableStart => {
        st.val = Variable
        if c == '{' {
          variable_chars.push(c)
          oc.val += 1
          false
        } else {
          variable_state(c, index, oc, st)
        }
      }
      WaitingListVariableIndex =>
        if c != '[' {
          true
        } else {
          index_chars.push(c)
          st.val = ListVariableIndex
          false
        }
      ListVariableIndex => {
        index_chars.push(c)
        c == ']'
      }
    }
    if stop {
      break
    }
    let scanning_index = st.val
      is (WaitingListVariableIndex | ListVariableIndex)
    if index == max_index && !scanning_index {
      break
    }
  }
  let n = variable_chars.length()
  let mut end = start + n
  let index = if !index_chars.is_empty() &&
    index_chars[index_chars.length() - 1] == ']' {
    end += index_chars.length()
    Some(rf_join(index_chars, 1, -1))
  } else {
    None
  }
  Some({
    identifier: variable_chars[0].to_string(),
    base: rf_join(variable_chars, 2, n - 1),
    index,
    start,
    end,
  })
}

///|
/// `VariableTokenizer.tokenize`.
fn rf_tokenize_variables(
  string : String,
  token : @token.TokenType,
  out : Array[(String, @token.TokenType)],
) -> Unit {
  let found = rf_split_variable(string, "$@%&")
  guard found is Some(v) && token != rf_comment && token != rf_error else {
    out.push((string, token))
  }
  let chars = string.to_array()
  let parts : Array[(String, @token.TokenType)] = []
  parts.push((rf_join(chars, 0, v.start), token))
  parts.push((v.identifier + "{", rf_syntax))
  rf_tokenize_variables(v.base, rf_variable, parts)
  parts.push(("}", rf_syntax))
  if v.index is Some(index) {
    parts.push(("[", rf_syntax))
    rf_tokenize_variables(index, rf_variable, parts)
    parts.push(("]", rf_syntax))
  }
  rf_tokenize_variables(rf_join(chars, v.end, chars.length()), token, parts)
  for p in parts {
    if p.0 != "" {
      out.push(p)
    }
  }
}

///|
/// `Tokenizer._is_assign`.
fn rf_is_assign(value : String) -> Bool {
  let value = if value.has_suffix("=") {
    markup_strip(@lexer.py_slice(value, 0, -1))
  } else {
    value
  }
  match rf_split_variable(value, "$@&") {
    Some(v) => v.start == 0 && v.end == value.to_array().length()
    None => false
  }
}

///|
let rf_gherkin_re : @regex.Regex = @lexer.re(
  "^(Given|When|Then|And|But) ",
  flags=@regex.IGNORECASE,
)

///|
/// `GherkinTokenizer().tokenize(value, token)`.
fn rf_gherkin_split(
  value : String,
  token : @token.TokenType,
) -> Array[(String, @token.TokenType)] {
  let found = rf_gherkin_re.match_at(value, 0) catch { _ => None }
  match found {
    None => [(value, token)]
    Some(m) =>
      [
        (value.unsafe_substring(start=0, end=m.end()), rf_gherkin),
        (value.unsafe_substring(start=m.end(), end=value.length()), token),
      ]
  }
}

///|
priv enum RfCellKind {
  Comment
  Setting
  TestCaseSetting
  KeywordSetting
  ImportSetting
  Variable
  KeywordCall
  TemplatedKeywordCall
  ForLoop
}

///|
/// A cell tokenizer (`Tokenizer` and its subclasses).
priv struct RfCell {
  kind : RfCellKind
  mut index : Int
  template_setter : ((String) -> Unit)?
  mut custom : RfCell?
  mut keyword_found : Bool
  mut assigns : Int
  mut in_arguments : Bool
}

///|
fn RfCell::new(
  kind : RfCellKind,
  template_setter? : (String) -> Unit,
  support_assign? : Bool = true,
) -> RfCell {
  {
    kind,
    index: 0,
    template_setter,
    custom: None,
    keyword_found: !support_assign,
    assigns: 0,
    in_arguments: false,
  }
}

///|
/// A `_tokenize` result: a token type or explicit `(value, token)` pairs.
priv enum RfRes {
  One(@token.TokenType)
  Many(Array[(String, @token.TokenType)])
}

///|
/// `Tokenizer._tokenize`: `_tokens[min(index, len - 1)]`.
fn RfCell::default_token(self : RfCell, index : Int) -> RfRes {
  let tokens = match self.kind {
    Comment => [rf_comment]
    Setting | TestCaseSetting | KeywordSetting => [rf_setting, rf_argument]
    ImportSetting => [rf_import, rf_argument]
    Variable => [rf_syntax, rf_argument]
    KeywordCall => [rf_keyword, rf_argument]
    TemplatedKeywordCall => [rf_argument]
    ForLoop => [rf_syntax]
  }
  let i = if index < tokens.length() - 1 { index } else { tokens.length() - 1 }
  let i = if i < 0 { i + tokens.length() } else { i }
  One(tokens[i])
}

///|
/// `Setting._tokenize` with the class-specific setting names.
fn RfCell::setting_tokenize(
  self : RfCell,
  value : String,
  index : Int,
) -> RfRes {
  let (keyword_settings, import_settings, other_settings) = match self.kind {
    TestCaseSetting =>
      (
        ["setup", "precondition", "teardown", "postcondition", "template"],
        [],
        ["documentation", "tags", "timeout"],
      )
    KeywordSetting =>
      (
        ["teardown"],
        [],
        ["documentation", "arguments", "return", "timeout", "tags"],
      )
    _ =>
      (
        [
          "suitesetup", "suiteprecondition", "suiteteardown", "suitepostcondition",
          "testsetup", "tasksetup", "testprecondition", "testteardown", "taskteardown",
          "testpostcondition", "testtemplate", "tasktemplate",
        ],
        ["library", "resource", "variables"],
        [
          "documentation", "metadata", "forcetags", "defaulttags", "testtimeout",
          "tasktimeout",
        ],
      )
  }
  if index == 1 && self.template_setter is Some(f) {
    f(value)
  }
  if index == 0 {
    let normalized = rf_normalize(value)
    if keyword_settings.contains(normalized) {
      self.custom = Some(RfCell::new(KeywordCall, support_assign=false))
    } else if import_settings.contains(normalized) {
      self.custom = Some(RfCell::new(ImportSetting))
    } else if !other_settings.contains(normalized) {
      return One(rf_error)
    }
  } else if self.custom is Some(custom) {
    return Many(custom.tokenize(value))
  }
  self.default_token(index)
}

///|
fn RfCell::tokenize_at(self : RfCell, value : String, index : Int) -> RfRes {
  match self.kind {
    Setting => self.setting_tokenize(value, index)
    TestCaseSetting | KeywordSetting =>
      if index == 0 {
        let inner = @lexer.py_slice(value, 1, -1)
        let t = match self.setting_tokenize(inner, index) {
          One(t) => t
          Many(_) => rf_error // unreachable: index 0 yields a token type
        }
        Many([("[", rf_syntax), (inner, t), ("]", rf_syntax)])
      } else {
        self.setting_tokenize(value, index)
      }
    Variable =>
      if index == 0 && !rf_is_assign(value) {
        One(rf_error)
      } else {
        self.default_token(index)
      }
    KeywordCall => {
      if !self.keyword_found && rf_is_assign(value) {
        self.assigns += 1
        return One(rf_syntax)
      }
      if self.keyword_found {
        return self.default_token(index - self.assigns)
      }
      self.keyword_found = true
      Many(rf_gherkin_split(value, rf_keyword))
    }
    ForLoop => {
      let token = if self.in_arguments { rf_argument } else { rf_syntax }
      let upper = value.to_upper()
      if upper == "IN" || upper == "IN RANGE" {
        self.in_arguments = true
      }
      One(token)
    }
    Comment | ImportSetting | TemplatedKeywordCall => self.default_token(index)
  }
}

///|
/// `Tokenizer.tokenize`.
fn RfCell::tokenize(
  self : RfCell,
  value : String,
) -> Array[(String, @token.TokenType)] {
  let res = self.tokenize_at(value, self.index)
  self.index += 1
  match res {
    One(t) => [(value, t)]
    Many(xs) => xs
  }
}

///|
priv enum RfTableKind {
  Unknown
  Variable
  Setting
  TestCase
  Keyword
}

///|
/// A table (`_Table` and its subclasses).
priv struct RfTable {
  kind : RfTableKind
  mut tokenizer : RfCell
  mut prev_tokenizer : RfCell?
  prev_values : Array[String]
  mut test_template : Bool?
  mut default_template : Bool?
  mut template_setter : ((String) -> Unit)?
}

///|
fn RfTable::new(kind : RfTableKind) -> RfTable {
  let t : RfTable = {
    kind,
    tokenizer: RfCell::new(Comment),
    prev_tokenizer: None,
    prev_values: [],
    test_template: None,
    default_template: None,
    template_setter: None,
  }
  t.tokenizer = t.new_tokenizer()
  t
}

///|
/// An instance of `_tokenizer_class`.
fn RfTable::new_tokenizer(self : RfTable) -> RfCell {
  match self.kind {
    Unknown => RfCell::new(Comment)
    Variable => RfCell::new(Variable)
    Setting => RfCell::new(Setting)
    Keyword => RfCell::new(KeywordCall)
    TestCase =>
      if self.test_template is Some(true) ||
        (
          self.default_template is Some(true) &&
          !(self.test_template is Some(false))
        ) {
        RfCell::new(TemplatedKeywordCall)
      } else {
        RfCell::new(KeywordCall)
      }
  }
}

///|
fn rf_is_template_set(template : String) -> Bool {
  !["", "\\", "none", "${empty}"].contains(rf_normalize(template))
}

///|
fn RfTable::continues(self : RfTable, value : String, index : Int) -> Bool {
  let base = () => {
    value == "..." && self.prev_values.iter().all(v => v == "" || v == "\\")
  }
  match self.kind {
    Unknown => false
    TestCase | Keyword => index > 0 && base()
    _ => base()
  }
}

///|
fn RfTable::tokenize_value(
  self : RfTable,
  value : String,
  index : Int,
) -> Array[(String, @token.TokenType)] {
  match self.kind {
    Setting =>
      if index == 0 && rf_normalize(value) == "testtemplate" {
        self.tokenizer = RfCell::new(
          Setting,
          template_setter?=self.template_setter,
        )
      }
    TestCase | Keyword => {
      if index == 0 {
        if value != "" {
          self.test_template = None
        }
        return rf_gherkin_split(value, rf_tc_kw_name)
      }
      let setting_class : RfCellKind = if self.kind is TestCase {
        TestCaseSetting
      } else {
        KeywordSetting
      }
      if index == 1 && value.has_prefix("[") && value.has_suffix("]") {
        if self.kind is TestCase && rf_normalize(value) == "[template]" {
          self.test_template = Some(false)
          self.tokenizer = RfCell::new(setting_class, template_setter=t => {
            self.test_template = Some(rf_is_template_set(t))
          })
        } else {
          self.tokenizer = RfCell::new(setting_class)
        }
      }
      if index == 1 &&
        value.has_prefix(":") &&
        rf_normalize(value, remove=":") == "for" {
        self.tokenizer = RfCell::new(ForLoop)
      }
      if index == 1 && (value == "" || value == "\\") {
        return [(value, rf_syntax)]
      }
    }
    _ => ()
  }
  self.tokenizer.tokenize(value)
}

///|
/// `_Table.tokenize`.
fn RfTable::tokenize(
  self : RfTable,
  value : String,
  index : Int,
) -> Array[(String, @token.TokenType)] {
  let out = if self.continues(value, index) {
    if self.prev_tokenizer is Some(p) {
      self.tokenizer = p
    }
    [(value, rf_syntax)]
  } else {
    self.tokenize_value(value, index)
  }
  self.prev_values.push(value)
  out
}

///|
fn RfTable::end_row(self : RfTable) -> Unit {
  self.prev_tokenizer = Some(self.tokenizer)
  self.prev_values.clear()
  self.tokenizer = self.new_tokenizer()
}

///|
let rf_space_splitter : @regex.Regex = @lexer.re("( {2,})")

///|
let rf_pipe_splitter : @regex.Regex = @lexer.re("((?:^| +)\\|(?: +|$))")

///|
/// `pattern.split(s, 1)` for the pipe splitter.
fn rf_pipe_split1(s : String) -> (String, String, String)? {
  let found = rf_pipe_splitter.search(s) catch { _ => None }
  match found {
    None => None
    Some(m) =>
      Some(
        (
          s.unsafe_substring(start=0, end=m.start()),
          m.matched(),
          s.unsafe_substring(start=m.end(), end=s.length()),
        ),
      )
  }
}

///|
/// `RowSplitter.split`.
fn rf_split_row(row : String) -> Array[String] {
  let out = []
  if row.has_prefix("| ") {
    match rf_pipe_split1(row) {
      Some((_, separator, rest)) => {
        out.push(separator)
        let mut rest = rest
        while rf_pipe_split1(rest) is Some((cell, separator, r)) {
          out.push(cell)
          out.push(separator)
          rest = r
        }
        out.push(rest)
      }
      None => ()
    }
  } else {
    out.push("")
    let parts = rf_space_splitter.split(row) catch { _ => [Some(row)] }
    for p in parts {
      out.push(p.unwrap_or(""))
    }
  }
  out.push("\n")
  out
}

///|
/// `RowTokenizer`.
priv struct RfRows {
  mut table : RfTable
  tables : Map[String, RfTable]
}

///|
fn RfRows::new() -> RfRows {
  let testcases = RfTable::new(TestCase)
  let settings = RfTable::new(Setting)
  settings.template_setter = Some(t => {
    testcases.default_template = Some(rf_is_template_set(t))
  })
  let variables = RfTable::new(Variable)
  let keywords = RfTable::new(Keyword)
  {
    table: RfTable::new(Unknown),
    tables: Map::from_array([
      ("settings", settings),
      ("setting", settings),
      ("metadata", settings),
      ("variables", variables),
      ("variable", variables),
      ("testcases", testcases),
      ("testcase", testcases),
      ("tasks", testcases),
      ("task", testcases),
      ("keywords", keywords),
      ("keyword", keywords),
      ("userkeywords", keywords),
      ("userkeyword", keywords),
    ]),
  }
}

///|
fn RfRows::tokenize(
  self : RfRows,
  row : String,
) -> Array[(String, @token.TokenType)] {
  let out = []
  let mut commented = false
  let mut heading = false
  for i, value in rf_split_row(row) {
    // divmod(i - 1, 2)
    let index = if i == 0 { -1 } else { (i - 1) / 2 }
    let separator = i % 2 == 0
    if value.has_prefix("#") {
      commented = true
    } else if index == 0 && value.has_prefix("*") {
      self.table = self.tables
        .get(rf_normalize(value, remove="*"))
        .unwrap_or(RfTable::new(Unknown))
      heading = true
    }
    if commented {
      out.push((value, rf_comment))
    } else if separator {
      out.push((value, rf_separator))
    } else if heading {
      out.push((value, rf_heading))
    } else {
      out.append(self.table.tokenize(value, index))
    }
  }
  self.table.end_row()
  out
}

///|
/// `RobotFrameworkLexer.get_tokens_unprocessed`. Python forces
/// `tabsize=2` in `__init__`; tabs are expanded here instead of in the
/// preprocessing step (equivalent for `get_tokens`).
#warnings("-unused_error_type")
fn robot_framework_lexer_tokenizer(
  _lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let text = @lexer.expand_tabs(text, 2)
  let rows = RfRows::new()
  let out : Array[@lexer.Token] = []
  let mut index = 0
  for row in splitlines(text) {
    for vt in rows.tokenize(row) {
      let parts = []
      rf_tokenize_variables(vt.0, vt.1, parts)
      for p in parts {
        if p.0 != "" {
          out.push({ index, ttype: p.1, value: p.0, })
          index += p.0.length()
        }
      }
    }
  }
  out
}
