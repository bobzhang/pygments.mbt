///|
/// One token produced by a lexer: its UTF-16 start offset, type and text.
pub(all) struct Token {
  index : Int
  ttype : @token.TokenType
  value : String
} derive(Eq, Debug)

///|
/// Static metadata of a lexer class (name, aliases, file patterns, ...).
pub(all) struct LexerInfo {
  /// Python class name, e.g. `PythonLexer`.
  class_name : String
  name : String
  aliases : Array[String]
  filenames : Array[String]
  alias_filenames : Array[String]
  mimetypes : Array[String]
  priority : Double
  url : String
  version_added : String
  /// Python's `analyse_text`: a score in `[0, 1]`.
  analyse_text : (String) -> Double
}

///|
/// A token stream filter (see `pygments.filters`).
pub(all) struct Filter {
  name : String
  apply : (Lexer?, Array[(@token.TokenType, String)]) -> Array[
    (@token.TokenType, String),
  ] raise
}

///|
/// Tokenizes preprocessed text starting from a state stack.
pub type Tokenizer = (Lexer, String, Array[String]) -> Array[Token] raise

///|
/// An instance of a lexer class with its options.
pub struct Lexer {
  info : LexerInfo
  options : Options
  priv create : (Options) -> Lexer raise
  priv tokenizer : Tokenizer
  stripnl : Bool
  stripall : Bool
  ensurenl : Bool
  tabsize : Int
  filters : Array[Filter]
}

///|
/// Builds a lexer instance. `create` must construct a new instance of the
/// same lexer class (used by `using(this, ...)`).
pub fn Lexer::new(
  info : LexerInfo,
  options : Options,
  create : (Options) -> Lexer raise,
  tokenizer : Tokenizer,
) -> Lexer raise OptionError {
  {
    info,
    options,
    create,
    tokenizer,
    stripnl: get_bool_opt(options, "stripnl", true),
    stripall: get_bool_opt(options, "stripall", false),
    ensurenl: get_bool_opt(options, "ensurenl", true),
    tabsize: get_int_opt(options, "tabsize", 0),
    filters: [],
  }
}

///|
/// Creates a new instance of the same lexer class with `options`.
pub fn Lexer::recreate(self : Lexer, options : Options) -> Lexer raise {
  (self.create)(options)
}

///|
/// Appends a filter to this lexer.
pub fn Lexer::add_filter(self : Lexer, f : Filter) -> Unit {
  self.filters.push(f)
}

///|
/// Default step budget for one lexing request (shared by nested lexers).
pub let default_budget_steps : Int = 2_000_000_000

///|
let current_budget : Ref[@regex.Budget] = Ref(
  @regex.Budget::new(default_budget_steps),
)

///|
let nesting : Ref[Int] = Ref(0)

///|
/// The budget of the lexing request in progress.
pub fn budget() -> @regex.Budget {
  current_budget.val
}

///|
/// Python's `get_tokens_unprocessed`: tokenizes `text` as is, starting with
/// `stack` (default `["root"]`). Offsets are UTF-16 offsets into `text`.
pub fn Lexer::get_tokens_unprocessed(
  self : Lexer,
  text : String,
  stack? : Array[String] = ["root"],
) -> Array[Token] raise {
  if nesting.val == 0 {
    current_budget.val = @regex.Budget::new(default_budget_steps)
  }
  nesting.val += 1
  defer {
    nesting.val -= 1
  }
  (self.tokenizer)(self, text, stack)
}

///|
/// Python's `Lexer._preprocess_lexer_input` for text input: drops a BOM,
/// normalizes newlines and applies `stripall`/`stripnl`/`tabsize`/`ensurenl`.
pub fn Lexer::preprocess(self : Lexer, text : String) -> String {
  let mut t = text
  if t.has_prefix("\u{feff}") {
    t = t.unsafe_substring(start=1, end=t.length())
  }
  t = t.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
  if self.stripall {
    t = strip_by(t, is_space)
  } else if self.stripnl {
    t = strip_by(t, c => c == '\n')
  }
  if self.tabsize > 0 {
    t = expand_tabs(t, self.tabsize)
  }
  if self.ensurenl && !t.has_suffix("\n") {
    t = t + "\n"
  }
  t
}

///|
fn strip_by(s : String, pred : (Char) -> Bool) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end && pred(s.unsafe_get(start).to_int().unsafe_to_char()) {
    start += 1
  }
  while end > start && pred(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
    end -= 1
  }
  s.unsafe_substring(start~, end~)
}

///|
/// Python's `str.expandtabs(tabsize)`.
pub fn expand_tabs(s : String, tabsize : Int) -> String {
  let sb = StringBuilder()
  let mut col = 0
  for c in s {
    if c == '\t' {
      let n = tabsize - col % tabsize
      for _ in 0..<n {
        sb.write_char(' ')
      }
      col += n
    } else {
      sb.write_char(c)
      if c == '\n' || c == '\r' {
        col = 0
      } else {
        col += 1
      }
    }
  }
  sb.to_string()
}

///|
/// Python's `Lexer.get_tokens`: preprocesses `text`, tokenizes it and applies
/// the lexer's filters (unless `unfiltered`).
pub fn Lexer::get_tokens(
  self : Lexer,
  text : String,
  unfiltered? : Bool = false,
) -> Array[(@token.TokenType, String)] raise {
  let t = self.preprocess(text)
  let mut stream = self
    .get_tokens_unprocessed(t)
    .map(tok => (tok.ttype, tok.value))
  if !unfiltered {
    for f in self.filters {
      stream = (f.apply)(Some(self), stream)
    }
  }
  stream
}

///|
/// A lexer's display name, e.g. `Python`.
pub fn Lexer::name(self : Lexer) -> String {
  self.info.name
}

///|
/// `analyse_text` of lexers that do not define one.
pub fn no_analyse(_text : String) -> Double {
  0.0
}

///|
/// Tokenizer of `TextLexer`: the whole input as one `Text` token.
pub fn text_tokenizer(
  _lexer : Lexer,
  text : String,
  _stack : Array[String],
) -> Array[Token] {
  [{ index: 0, ttype: @token.text, value: text, }]
}
