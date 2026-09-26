///|
/// A token stream: `(token type, text)` pairs, as produced by
/// `@lexer.Lexer::get_tokens`.
pub type Tokens = Array[(@token.TokenType, String)]

///|
/// Errors raised by formatters (Python's `ValueError`/`RuntimeError`/...).
pub suberror FormatterError {
  FormatterError(String)
} derive(Debug)

///|
/// Raised when no formatter matches a lookup (Python's `ClassNotFound`).
pub suberror ClassNotFound {
  ClassNotFound(String)
} derive(Debug)

///|
/// Static metadata of a formatter class.
pub(all) struct FormatterInfo {
  /// Python class name, e.g. `HtmlFormatter`.
  class_name : String
  /// Human-readable name (`HTML`).
  name : String
  aliases : Array[String]
  /// `fnmatch` patterns of the file names this formatter can produce.
  filenames : Array[String]
  /// First paragraph of the class docstring.
  description : String
} derive(Debug)

///|
/// The options every formatter accepts (Python's `Formatter.__init__`).
pub struct BaseOptions {
  style : @styles.Style
  full : Bool
  title : String
  /// Python's `encoding` (`None` when unset). Output is always a `String`;
  /// the encoding only shows up in document headers.
  encoding : String?
  options : @lexer.Options
}

///|
/// Parses the common options. `style` overrides the `style` option (like
/// passing a `Style` class in Python).
pub fn BaseOptions::new(
  options : @lexer.Options,
  style? : @styles.Style,
) -> BaseOptions raise {
  let style = match style {
    Some(s) => s
    None => @styles.get_style_by_name(options.get("style").unwrap_or("default"))
  }
  let full = @lexer.get_bool_opt(options, "full", false)
  let title = options.get("title").unwrap_or("")
  let mut encoding = match options.get("encoding") {
    Some("") | None => None
    Some("guess") | Some("chardet") => Some("utf-8")
    Some(e) => Some(e)
  }
  match options.get("outencoding") {
    Some("") | None => ()
    Some(e) => encoding = Some(e)
  }
  { style, full, title, encoding, options, }
}

///|
/// A formatter instance: converts a token stream to text.
pub struct Formatter {
  info : FormatterInfo
  base : BaseOptions
  priv format_fn : (Tokens) -> String raise
  priv style_defs_fn : (String?) -> String raise
  priv aux_files_fn : () -> Array[AuxFile]
}

///|
/// A file that Python's formatter writes as a side effect of `format`
/// (the HTML formatter's `cssfile`). This port does no file IO: the caller
/// writes `contents` to `path`, which Python resolves relative to the
/// directory of the output file (or the current directory when the output
/// has no name) unless it is absolute; with `noclobber` an existing file is
/// kept.
pub(all) struct AuxFile {
  path : String
  contents : String
  noclobber : Bool
} derive(Debug)

///|
/// Wraps the operations of a formatter class.
pub fn Formatter::new(
  info : FormatterInfo,
  base : BaseOptions,
  format : (Tokens) -> String raise,
  style_defs? : (String?) -> String raise = _ => "",
  aux_files? : () -> Array[AuxFile] = () => [],
) -> Formatter {
  {
    info,
    base,
    format_fn: format,
    style_defs_fn: style_defs,
    aux_files_fn: aux_files,
  }
}

///|
/// The files Python would write while formatting (see `AuxFile`).
pub fn Formatter::aux_files(self : Formatter) -> Array[AuxFile] {
  (self.aux_files_fn)()
}

///|
/// Python's `Formatter.format`: the formatted text of `tokens`.
pub fn Formatter::format(self : Formatter, tokens : Tokens) -> String raise {
  (self.format_fn)(tokens)
}

///|
/// Python's `get_style_defs(arg)`: style definitions for the current style
/// (e.g. CSS rules for HTML). Omitting `arg` is Python's `arg=None`; the
/// `pygmentize -S` command line passes `arg` (default `""`).
pub fn Formatter::get_style_defs(
  self : Formatter,
  arg? : String,
) -> String raise {
  (self.style_defs_fn)(arg)
}

///|
/// Python's `pygments.highlight`: lexes `code` with `lexer` (including its
/// filters) and formats the tokens with `formatter`.
pub fn highlight(
  code : String,
  lexer : @lexer.Lexer,
  formatter : Formatter,
) -> String raise {
  formatter.format(lexer.get_tokens(code))
}

///|
/// The formatter's human-readable name.
pub fn Formatter::name(self : Formatter) -> String {
  self.info.name
}

///|
/// The formatter's aliases.
pub fn Formatter::aliases(self : Formatter) -> Array[String] {
  self.info.aliases
}

///|
/// The formatter's file name patterns.
pub fn Formatter::filenames(self : Formatter) -> Array[String] {
  self.info.filenames
}

///|
/// The options the formatter was created with.
pub fn Formatter::options(self : Formatter) -> @lexer.Options {
  self.base.options
}

///|
/// The style the formatter uses.
pub fn Formatter::style(self : Formatter) -> @styles.Style {
  self.base.style
}
