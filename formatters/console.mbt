///|
/// Python's `pygments.console.codes`: ANSI escape sequences by name.
pub let console_codes : Map[String, String] = {
  let esc = "\u{1b}["
  let codes : Map[String, String] = Map([
    ("", ""),
    ("reset", esc + "39;49;00m"),
    ("bold", esc + "01m"),
    ("faint", esc + "02m"),
    ("standout", esc + "03m"),
    ("underline", esc + "04m"),
    ("blink", esc + "05m"),
    ("overline", esc + "06m"),
  ])
  let dark = [
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "gray",
  ]
  let light = [
    "brightblack", "brightred", "brightgreen", "brightyellow", "brightblue", "brightmagenta",
    "brightcyan", "white",
  ]
  for i in 0..<8 {
    codes[dark[i]] = esc + (30 + i).to_string() + "m"
    codes[light[i]] = esc + (90 + i).to_string() + "m"
  }
  codes["white"] = codes["bold"]
  codes
}

///|
/// Python's `pygments.console.colorize`.
pub fn colorize(
  color_key : String,
  text : String,
) -> String raise FormatterError {
  match console_codes.get(color_key) {
    Some(c) => c + text + console_codes["reset"]
    None => raise FormatterError("KeyError: \{@pystr.repr(color_key)}")
  }
}

///|
/// Whether `attr` starts and ends with `ch` (Python's
/// `attr[:1] == attr[-1:] == ch`).
fn wrapped_in(attr : String, ch : Char) -> Bool {
  attr.length() > 0 &&
  attr.get_char(0) == Some(ch) &&
  attr.unsafe_get(attr.length() - 1).to_int() == ch.to_int()
}

///|
/// `attr[1:-1]`.
fn strip_one(attr : String) -> String {
  if attr.length() < 2 {
    ""
  } else {
    attr.unsafe_substring(start=1, end=attr.length() - 1)
  }
}

///|
/// Python's `pygments.console.ansiformat`: `text` in a color, where
/// `*color*` is bold, `_color_` underlined and `+color+` blinking.
pub fn ansiformat(attr : String, text : String) -> String raise FormatterError {
  let buf = StringBuilder()
  let mut attr = attr
  if wrapped_in(attr, '+') {
    buf.write_string(console_codes["blink"])
    attr = strip_one(attr)
  }
  if wrapped_in(attr, '*') {
    buf.write_string(console_codes["bold"])
    attr = strip_one(attr)
  }
  if wrapped_in(attr, '_') {
    buf.write_string(console_codes["underline"])
    attr = strip_one(attr)
  }
  match console_codes.get(attr) {
    Some(c) => buf.write_string(c)
    None => raise FormatterError("KeyError: \{@pystr.repr(attr)}")
  }
  buf.write_string(text)
  buf.write_string(console_codes["reset"])
  buf.to_string()
}
