///|
/// Lexer, formatter and filter options. As on the pygmentize command line,
/// every value is a string; typed accessors mirror `pygments.util`.
pub type Options = Map[String, String]

///|
/// Errors raised for invalid option values.
pub suberror OptionError {
  OptionError(String)
} derive(Debug)

///|
/// Python's `get_bool_opt`.
pub fn get_bool_opt(
  options : Options,
  name : String,
  default : Bool,
) -> Bool raise OptionError {
  match options.get(name) {
    None => default
    Some(v) =>
      match v.to_lower() {
        "1" | "yes" | "true" | "on" => true
        "0" | "no" | "false" | "off" => false
        _ =>
          raise OptionError(
            "Invalid value \{v.escape()} for option \{name}; use 1/0, yes/no, true/false, on/off",
          )
      }
  }
}

///|
/// Python's `get_int_opt`.
pub fn get_int_opt(
  options : Options,
  name : String,
  default : Int,
) -> Int raise OptionError {
  match options.get(name) {
    None => default
    Some(v) =>
      @string.parse_int(v.trim()) catch {
        _ =>
          raise OptionError(
            "Invalid value \{v.escape()} for option \{name}; you must give an integer value",
          )
      }
  }
}

///|
/// Python's `get_list_opt`: the value split at whitespace.
pub fn get_list_opt(
  options : Options,
  name : String,
  default : Array[String],
) -> Array[String] {
  match options.get(name) {
    None => default
    Some(v) => split_whitespace(v)
  }
}

///|
/// Python's `get_choice_opt`.
pub fn get_choice_opt(
  options : Options,
  name : String,
  allowed : Array[String],
  default : String,
  normcase? : Bool = false,
) -> String raise OptionError {
  let v = options.get(name).unwrap_or(default)
  let v = if normcase { v.to_lower() } else { v }
  if !allowed.contains(v) {
    raise OptionError(
      "Value for option \{name} must be one of \{allowed.join(", ")}",
    )
  }
  v
}

///|
/// Python's `str.split()` without arguments.
pub fn split_whitespace(s : String) -> Array[String] {
  let out = []
  let buf = StringBuilder()
  let mut pending = false
  for c in s {
    if is_space(c) {
      if pending {
        out.push(buf.to_string())
        buf.reset()
        pending = false
      }
    } else {
      buf.write_char(c)
      pending = true
    }
  }
  if pending {
    out.push(buf.to_string())
  }
  out
}

///|
/// Python's `str.isspace` for one character.
pub fn is_space(c : Char) -> Bool {
  match c {
    ' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' => true
    '\u{1c}'..='\u{1f}' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' => true
    '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}
