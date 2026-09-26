///|
/// Parsed command line of `pygmentize` (mirrors Python's argparse setup in
/// `pygments/cmdline.py`).
priv struct Args {
  mut lexer : String?
  mut guess : Bool
  filters : Array[String]
  mut formatter : String?
  options : Array[String]
  single_options : Array[String]
  mut output : String?
  mut input : String?
  mut verbose : Bool
  mut stream : Bool
  mut custom : Bool
  mut json : Bool
  mut style : String?
  mut list : Array[String]?
  mut name_for_file : String?
  mut guess_stdin : Bool
  mut help_on : (String, String)?
  mut version : Bool
  mut help : Bool
  mut style_arg : String?
}

///|
priv suberror UsageError {
  UsageError(String)
}

///|
fn Args::new() -> Args {
  {
    lexer: None,
    guess: false,
    filters: [],
    formatter: None,
    options: [],
    single_options: [],
    output: None,
    input: None,
    verbose: false,
    stream: false,
    custom: false,
    json: false,
    style: None,
    list: None,
    name_for_file: None,
    guess_stdin: false,
    help_on: None,
    version: false,
    help: false,
    style_arg: None,
  }
}

///|
/// Short options that take a value.
fn takes_value(c : Char) -> Bool {
  match c {
    'l' | 'F' | 'f' | 'O' | 'P' | 'o' | 'S' | 'N' | 'a' => true
    _ => false
  }
}

///|
fn Args::set_value(self : Args, c : Char, v : String) -> Unit {
  match c {
    'l' => self.lexer = Some(v)
    'F' => self.filters.push(v)
    'f' => self.formatter = Some(v)
    'O' => self.options.push(v)
    'P' => self.single_options.push(v)
    'o' => self.output = Some(v)
    'S' => self.style = Some(v)
    'N' => self.name_for_file = Some(v)
    _ => self.style_arg = Some(v)
  }
}

///|
fn parse_args(argv : Array[String]) -> Args raise UsageError {
  let a = Args::new()
  let mut i = 0
  let mut only_positional = false
  while i < argv.length() {
    let arg = argv[i]
    i += 1
    if only_positional || !arg.has_prefix("-") || arg == "-" {
      if a.input is Some(_) {
        raise UsageError("unrecognized arguments: \{arg}")
      }
      a.input = Some(arg)
      continue
    }
    match arg {
      "--" => {
        only_positional = true
        continue
      }
      "--help" => {
        a.help = true
        continue
      }
      "--json" => {
        a.json = true
        continue
      }
      _ => ()
    }
    if arg.has_prefix("--") {
      raise UsageError("unrecognized arguments: \{arg}")
    }
    let chars = arg.to_array()
    let mut k = 1
    while k < chars.length() {
      let c = chars[k]
      k += 1
      if takes_value(c) {
        let v = if k < chars.length() {
          String::from_array(chars[k:])
        } else if i < argv.length() {
          i += 1
          argv[i - 1]
        } else {
          raise UsageError("argument -\{c}: expected one argument")
        }
        a.set_value(c, v)
        break
      }
      match c {
        'g' => a.guess = true
        'v' => a.verbose = true
        's' => a.stream = true
        'x' => a.custom = true
        'C' => a.guess_stdin = true
        'V' => a.version = true
        'h' => a.help = true
        'L' => {
          let what = []
          if k < chars.length() {
            what.push(String::from_array(chars[k:]))
            k = chars.length()
          }
          while i < argv.length() && !argv[i].has_prefix("-") {
            what.push(argv[i])
            i += 1
          }
          a.list = Some(what)
        }
        'H' => {
          if i + 1 >= argv.length() {
            raise UsageError("argument -H: expected 2 arguments")
          }
          a.help_on = Some((argv[i], argv[i + 1]))
          i += 2
        }
        _ => raise UsageError("unrecognized arguments: \{arg}")
      }
    }
  }
  if a.lexer is Some(_) && a.guess {
    raise UsageError("argument -g: not allowed with argument -l")
  }
  let special = [
    a.style is Some(_),
    a.list is Some(_),
    a.name_for_file is Some(_),
    a.guess_stdin,
    a.help_on is Some(_),
    a.version,
    a.help,
  ]
  if special.filter(x => x).length() > 1 {
    raise UsageError("special modes are mutually exclusive")
  }
  a
}

///|
/// Whether any option besides the special mode itself was given (Python's
/// `is_only_option`).
fn Args::has_other_than(self : Args, mode : String) -> Bool {
  let checks = [
    ("l", self.lexer is Some(_)),
    ("g", self.guess),
    ("F", !self.filters.is_empty()),
    ("f", self.formatter is Some(_)),
    ("O", !self.options.is_empty()),
    ("P", !self.single_options.is_empty()),
    ("o", self.output is Some(_)),
    ("INPUTFILE", self.input is Some(_)),
    ("v", self.verbose),
    ("s", self.stream),
    ("x", self.custom),
    ("json", self.json),
    ("S", self.style is Some(_)),
    ("N", self.name_for_file is Some(_)),
    ("C", self.guess_stdin),
    ("H", self.help_on is Some(_)),
    ("V", self.version),
    ("h", self.help),
    ("a", self.style_arg is Some(_)),
  ]
  checks.iter().any(c => c.0 != mode && c.1)
}

///|
let usage : String =
  #|usage: pygmentize [-l LEXER | -g] [-F FILTER[:options]] [-f FORMATTER]
  #|                  [-O OPTION=value[,OPTION=value,...]] [-P OPTION=value]
  #|                  [-o OUTPUTFILE] [-v] [-s] [-x] [--json]
  #|                  [-S STYLE -f formatter | -L [WHAT ...] | -N FILENAME | -C |
  #|                  -H NAME TYPE | -V | -h] [-a ARG]
  #|                  [INPUTFILE]
  #|

///|
let help_text : String =
  #|
  #|Highlight an input file and write the result to an output file.
  #|
  #|Main operation:
  #|  -l LEXER        Specify the lexer to use. (Query names with -L.) If not
  #|                  given and -g is not present, the lexer is guessed from the
  #|                  filename.
  #|  -g              Guess the lexer from the file contents, or pass through as
  #|                  plain text if nothing can be guessed.
  #|  -F FILTER[:options]
  #|                  Add a filter to the token stream. (Query names with -L.)
  #|                  Filter options are given after a colon if necessary.
  #|  -f FORMATTER    Specify the formatter to use. (Query names with -L.) If not
  #|                  given, the formatter is guessed from the output filename,
  #|                  and defaults to the terminal formatter if the output is to
  #|                  the terminal or an unknown file extension.
  #|  -O OPTION=value[,OPTION=value,...]
  #|                  Give options to the lexer and formatter as a comma-
  #|                  separated list of key-value pairs. Example: `-O
  #|                  bg=light,python=cool`.
  #|  -P OPTION=value  Give a single option to the lexer and formatter - with
  #|                  this you can pass options whose value contains commas and
  #|                  equal signs. Example: `-P "heading=Pygments, the Python
  #|                  highlighter"`.
  #|  -o OUTPUTFILE   Where to write the output. Defaults to standard output.
  #|  INPUTFILE       Where to read the input. Defaults to standard input.
  #|
  #|Operation flags:
  #|  -v              Print a detailed traceback on unhandled exceptions, which
  #|                  is useful for debugging and bug reports.
  #|  -s              Process lines one at a time until EOF, rather than waiting
  #|                  to process the entire file. This only works for stdin,
  #|                  only for lexers with no line-spanning constructs, and is
  #|                  intended for streaming input such as you get from `tail
  #|                  -f`. Example usage: `tail -f sql.log | pygmentize -s -l
  #|                  sql`.
  #|  -x              Allow custom lexers and formatters to be loaded from a .py
  #|                  file (not supported by the MoonBit port).
  #|  --json          Output as JSON. This can be only used in conjunction with
  #|                  -L.
  #|
  #|Special modes - do not do any highlighting:
  #|  -S STYLE -f formatter
  #|                  Print style definitions for STYLE for a formatter given
  #|                  with -f. The argument given by -a is formatter dependent.
  #|  -L [WHAT ...]   List lexers, formatters, styles or filters -- give
  #|                  additional arguments for the thing(s) you want to list
  #|                  (e.g. "styles"), or omit them to list everything.
  #|  -N FILENAME     Guess and print out a lexer name based solely on the given
  #|                  filename. Does not take input or highlight anything. If no
  #|                  specific lexer can be determined, "text" is printed.
  #|  -C              Like -N, but print out a lexer name based solely on a given
  #|                  content from standard input.
  #|  -H NAME TYPE    Print detailed help for the object <name> of type <type>,
  #|                  where <type> is one of "lexer", "formatter" or "filter".
  #|  -V              Print the package version.
  #|  -h, --help      Print this help.
  #|  -a ARG          Formatter-specific additional argument for the -S (print
  #|                  style sheet) mode.
  #|

///|
/// Python's `_parse_options`: comma-separated `key=value` pairs; a bare key
/// means `True`.
fn parse_options(o_strs : Array[String], into : Map[String, String]) -> Unit {
  for o_str in o_strs {
    if o_str.trim().length() == 0 {
      continue
    }
    for o_arg in o_str.split(",") {
      let o_arg = o_arg.trim().to_owned()
      match o_arg.find("=") {
        Some(i) =>
          into[o_arg.unsafe_substring(start=0, end=i).trim().to_owned()] = o_arg
            .unsafe_substring(start=i + 1, end=o_arg.length())
            .trim()
            .to_owned()
        None => into[o_arg] = "True"
      }
    }
  }
}

///|
/// Python's `_parse_filters`: `name[:options]`.
fn parse_filters(
  f_strs : Array[String],
) -> Array[(String, Map[String, String])] {
  f_strs.map(f => {
    match f.find(":") {
      Some(i) => {
        let opts : Map[String, String] = Map([])
        parse_options([f.unsafe_substring(start=i + 1, end=f.length())], opts)
        (f.unsafe_substring(start=0, end=i), opts)
      }
      None => (f, Map([]))
    }
  })
}
