///|
/// Raised when no style matches a lookup (Python's `ClassNotFound`).
pub suberror ClassNotFound {
  ClassNotFound(String)
} derive(Debug)

///|
/// Builtin styles constructed so far, by style name.
let style_cache : Map[String, Style] = Map([])

///|
/// Returns the cached builtin style `name`, building it on first use.
fn builtin(name : String, build : () -> Style) -> Style {
  style_cache.get_or_init(name, build)
}

///|
/// Constructor used by the generated `gen_*.mbt` files.
fn make(
  name : String,
  aliases : Array[String],
  background_color : String?,
  highlight_color : String?,
  line_number_color : String,
  line_number_background_color : String,
  line_number_special_color : String,
  line_number_special_background_color : String,
  web_style_gallery_exclude : Bool,
  styles : Array[(String, String)],
) -> Style {
  Style::new(
    styles.map(p => (@token.from_string(p.0), p.1)),
    name~,
    aliases~,
    background_color~,
    highlight_color~,
    line_number_color~,
    line_number_background_color~,
    line_number_special_color~,
    line_number_special_background_color~,
    web_style_gallery_exclude~,
  ) catch {
    _ => abort("invalid builtin style \{name}")
  }
}

///|
/// Python's `get_style_by_name`: the builtin style called `name`.
///
/// ```mbt check
/// test {
///   let st = @styles.get_style_by_name("monokai")
///   inspect(st.background_color.unwrap_or("-"), content="#272822")
///   try @styles.get_style_by_name("nope") catch {
///     ClassNotFound(msg) =>
///       inspect(
///         msg,
///         content="Could not find style module 'pygments.styles.nope'.",
///       )
///   } noraise {
///     _ => fail("expected ClassNotFound")
///   }
/// }
/// ```
pub fn get_style_by_name(name : String) -> Style raise ClassNotFound {
  for entry in builtin_styles {
    if entry.0 == name {
      return (entry.1)()
    }
  }
  raise ClassNotFound("Could not find style module 'pygments.styles.\{name}'.")
}

///|
/// Python's `get_all_styles`: the names of all builtin styles.
pub fn get_all_styles() -> Array[String] {
  builtin_styles.map(e => e.0)
}
