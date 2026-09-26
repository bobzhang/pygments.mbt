///|
/// Raised when no filter matches a lookup (Python's `ClassNotFound`).
pub suberror ClassNotFound {
  ClassNotFound(String)
} derive(Debug)

///|
/// Python's `FILTERS`: filter names and constructors, in Python's order.
let all_filters : Array[(String, (@lexer.Options) -> @lexer.Filter raise)] = [
  ("codetagify", options => code_tag_filter(options~)),
  ("keywordcase", options => keyword_case_filter(options~)),
  ("highlight", options => name_highlight_filter(options~)),
  ("raiseonerror", options => raise_on_error_token_filter(options~)),
  ("whitespace", options => visible_whitespace_filter(options~)),
  ("gobble", options => gobble_filter(options~)),
  ("tokenmerge", options => token_merge_filter(options~)),
  ("symbols", options => symbol_filter(options~)),
]

///|
/// Python's `find_filter_class`: whether a filter called `name` exists.
pub fn find_filter(name : String) -> Bool {
  all_filters.iter().any(e => e.0 == name)
}

///|
/// Python's `get_filter_by_name`: an instance of the filter `name`
/// configured with `options`.
///
/// ```mbt check
/// test {
///   let f = @filters.get_filter_by_name("keywordcase", options={ "case": "upper" })
///   let out = (f.apply)(None, [(@token.keyword, "def"), (@token.name, "f")])
///   inspect(out.map(t => t.1).join(" "), content="DEF f")
/// }
/// ```
pub fn get_filter_by_name(
  name : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Filter raise {
  for entry in all_filters {
    if entry.0 == name {
      return (entry.1)(options)
    }
  }
  raise ClassNotFound("filter \{@pystr.repr(name)} not found")
}

///|
/// Python's `get_all_filters`: the names of all filters.
pub fn get_all_filters() -> Array[String] {
  all_filters.map(e => e.0)
}

///|
/// Python's `apply_filters`: runs `stream` through `filters` in order.
pub fn apply_filters(
  stream : Array[(@token.TokenType, String)],
  filters : Array[@lexer.Filter],
  lexer? : @lexer.Lexer,
) -> Array[(@token.TokenType, String)] raise {
  let mut s = stream
  for f in filters {
    s = (f.apply)(lexer, s)
  }
  s
}
