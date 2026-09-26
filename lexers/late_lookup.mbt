// Registry lookups for lexers that pick a sub-lexer at run time (Markdown
// code blocks, HTTP bodies, ...). A lexer constructor cannot refer to
// `get_lexer_by_name` directly: that would be a definition cycle through the
// `all_lexers` table, so the lookups are bound at package initialization.

///|
let late_lookup_by_name : Ref[(String, @lexer.Options) -> @lexer.Lexer raise] = Ref((
    name,
    _,
  ) => raise ClassNotFound(name),
)

///|
let late_lookup_for_mimetype : Ref[(String) -> @lexer.Lexer raise] = Ref(mime => {
  raise ClassNotFound(mime)
})

///|
let late_lookup_guess : Ref[(String) -> @lexer.Lexer raise] = Ref(_ => {
  raise ClassNotFound("guess")
})

///|
fn init {
  late_lookup_by_name.val = (name, options) => get_lexer_by_name(name, options~)
  late_lookup_for_mimetype.val = mime => get_lexer_for_mimetype(mime)
  late_lookup_guess.val = text => guess_lexer(text)
}

///|
/// Runs a lookup, mapping `ClassNotFound` to `None`.
fn late_lookup(
  f : (String) -> @lexer.Lexer raise,
  arg : String,
) -> @lexer.Lexer? raise {
  try f(arg) catch {
    ClassNotFound(_) => None
    e => raise e
  } noraise {
    lx => Some(lx)
  }
}

///|
/// `get_lexer_by_name(name)`, `None` on `ClassNotFound`.
fn late_lexer_by_name(name : String) -> @lexer.Lexer? raise {
  late_lookup(name => (late_lookup_by_name.val)(name, Map([])), name)
}

///|
/// `get_lexer_for_mimetype(mime)`, `None` on `ClassNotFound`.
fn late_lexer_for_mimetype(mime : String) -> @lexer.Lexer? raise {
  late_lookup(late_lookup_for_mimetype.val, mime)
}

///|
/// `guess_lexer(text)`, `None` on `ClassNotFound`.
fn late_guess_lexer(text : String) -> @lexer.Lexer? raise {
  late_lookup(late_lookup_guess.val, text)
}

///|
/// `get_lexer_by_name(name, **options)` for use inside lexers; raises
/// `ClassNotFound`.
fn lookup_lexer(
  name : String,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  (late_lookup_by_name.val)(name, options)
}
