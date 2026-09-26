///|
/// `pygmentize`: highlight an input file and write the result to an output
/// file (a port of `pygments/cmdline.py`).
async fn main {
  let argv = @env.args()
  let code = run(argv[1:].to_owned()) catch {
    e => {
      eprint("\n*** Error while highlighting:\n\{error_message(e)}\n")
      eprint("*** If this is a bug you want to report, please rerun with -v.\n")
      1
    }
  }
  @sys.exit(code)
}

///|
async fn eprint(s : String) -> Unit {
  @stdio.stderr.write(s)
}

///|
async fn print(s : String) -> Unit {
  @stdio.stdout.write(s)
}

///|
fn error_message(e : Error) -> String {
  match e {
    @lexers.ClassNotFound(msg) => msg
    @lexer.OptionError(msg) => msg
    @formatters.ClassNotFound(msg) => msg
    @formatters.FormatterError(msg) => msg
    _ => Repr(e).to_string()
  }
}

///|
/// Python's `str(OSError)`: `[Errno N] message: 'path'`.
fn os_error_message(e : Error, path : String) -> String {
  match e {
    @os_error.OSError(errno, ..) as e =>
      "[Errno \{errno}] \{os_message(e)}: \{@pystr.repr(path)}"
    _ => error_message(e)
  }
}

///|
/// Decodes input bytes like Python's `guess_decode`: UTF-8 (dropping a BOM),
/// falling back to Latin-1.
fn guess_decode(data : Bytes) -> String {
  @utf8.decode(data, ignore_bom=true) catch {
    _ => {
      let sb = StringBuilder()
      for b in data {
        sb.write_char(b.to_int().unsafe_to_char())
      }
      sb.to_string()
    }
  }
}

///|
async fn read_stdin() -> String {
  guess_decode(@stdio.stdin.read_all().binary())
}

///|
async fn usage_error(msg : String) -> Int {
  eprint(usage)
  eprint("pygmentize: error: \{msg}\n")
  2
}

///|
async fn print_usage_help() -> Int {
  eprint(usage + help_text)
  2
}

///|
async fn run(argv : Array[String]) -> Int {
  let args = parse_args(argv) catch {
    UsageError(msg) => return usage_error(msg)
  }
  if args.help {
    print(usage + help_text)
    return 0
  }
  if args.version {
    print(version_line + "\n")
    return 0
  }
  // -L
  if args.list is Some(what) {
    if args.has_other_than("L") && !(args.json && !args.has_other_than("json")) {
      if [
          args.lexer is Some(_),
          args.guess,
          args.formatter is Some(_),
          args.input is Some(_),
          args.output is Some(_),
          !args.options.is_empty(),
        ]
        .iter()
        .any(x => x) {
        return print_usage_help()
      }
    }
    let kinds = what.map(w => {
      if w.has_suffix("s") {
        w.unsafe_substring(start=0, end=w.length() - 1)
      } else {
        w
      }
    })
    let allowed = ["lexer", "formatter", "filter", "style"]
    if kinds.iter().any(k => !allowed.contains(k)) {
      return print_usage_help()
    }
    let kinds = if kinds.is_empty() { allowed } else { kinds }
    if args.json {
      print(list_as_json(kinds))
    } else {
      print(version_line + "\n")
      for k in kinds {
        print(list_what(k))
      }
    }
    return 0
  }
  // -H
  if args.help_on is Some((what, name)) {
    if args.has_other_than("H") {
      return print_usage_help()
    }
    if !["lexer", "formatter", "filter"].contains(what) {
      return print_usage_help()
    }
    match help_on(what, name) {
      Some(text) => {
        print(text)
        return 0
      }
      None => {
        eprint("\{what} not found!\n")
        return 1
      }
    }
  }
  // -O and -P
  let options : Map[String, String] = Map([])
  parse_options(args.options, options)
  for p in args.single_options {
    match p.find("=") {
      Some(i) =>
        options[p.unsafe_substring(start=0, end=i)] = p.unsafe_substring(
          start=i + 1,
          end=p.length(),
        )
      None => options[p] = "True"
    }
  }
  // -N
  if args.name_for_file is Some(fname) {
    let aliases = match @lexers.find_lexer_class_for_filename(fname) {
      Some(entry) => entry.0.aliases
      None => @lexers.text_lexer_info.aliases
    }
    print(aliases[0] + "\n")
    return 0
  }
  // -C
  if args.guess_stdin {
    let text = read_stdin()
    let aliases = @lexers.guess_lexer(text).info.aliases catch {
        _ => @lexers.text_lexer_info.aliases
      }
    print(aliases[0] + "\n")
    return 0
  }
  // -S
  if args.style is Some(style) {
    guard args.formatter is Some(f) else { return print_usage_help() }
    if args.lexer is Some(_) || args.input is Some(_) {
      return print_usage_help()
    }
    options["style"] = style
    let fmter = @formatters.get_formatter_by_name(f, options~) catch {
      e => {
        eprint(error_message(e) + "\n")
        return 1
      }
    }
    print(fmter.get_style_defs(arg=args.style_arg.unwrap_or("")) + "\n")
    return 0
  }
  if args.style_arg is Some(_) {
    return print_usage_help()
  }
  let filters = parse_filters(args.filters)
  if args.custom {
    eprint(
      "Error: custom lexers and formatters (-x) are not supported by the MoonBit port\n",
    )
    return 1
  }
  // select lexer
  let mut lexer : @lexer.Lexer? = None
  if args.lexer is Some(name) {
    lexer = Some(
      @lexers.get_lexer_by_name(name, options~) catch {
        e => {
          eprint("Error: \{error_message(e)}\n")
          return 1
        }
      },
    )
  }
  // read input
  let mut code = ""
  match args.input {
    Some(infn) => {
      if args.stream {
        eprint("Error: -s option not usable when input file specified\n")
        return 2
      }
      let data = @fs.read_file(infn) catch {
        e => {
          eprint("Error: cannot read infile: \{os_error_message(e, infn)}\n")
          return 1
        }
      }
      code = guess_decode(data.binary())
      if lexer is None {
        lexer = Some(
          @lexers.get_lexer_for_filename(infn, code~, options~) catch {
            @lexers.ClassNotFound(_) if args.guess =>
              @lexers.guess_lexer(code, options~) catch {
                _ => @lexers.text_lexer(options~)
              }
            e => {
              eprint("Error: \{error_message(e)}\n")
              return 1
            }
          },
        )
      }
    }
    None =>
      if !args.stream {
        code = read_stdin()
        if lexer is None {
          lexer = Some(
            @lexers.guess_lexer(code, options~) catch {
              _ => @lexers.text_lexer(options~)
            },
          )
        }
      } else if lexer is None {
        eprint("Error: when using -s a lexer has to be selected with -l\n")
        return 2
      }
  }
  let lexer = lexer.unwrap()
  // filters
  for f in filters {
    let filter = @filters.get_filter_by_name(f.0, options=f.1) catch {
      e => {
        eprint("Error: \{error_message(e)}\n")
        return 1
      }
    }
    lexer.add_filter(filter)
  }
  // select formatter; like Python, the output encoding defaults to the
  // input/terminal encoding (always UTF-8 here)
  let fopts = options.copy()
  if !fopts.contains("outencoding") && !fopts.contains("encoding") {
    fopts["outencoding"] = "utf-8"
  }
  let options = fopts
  let fmter = match args.formatter {
    Some(name) =>
      @formatters.get_formatter_by_name(name, options~) catch {
        e => {
          eprint("Error: \{error_message(e)}\n")
          return 1
        }
      }
    None =>
      match args.output {
        Some(outfn) =>
          @formatters.get_formatter_for_filename(outfn, options~) catch {
            e => {
              eprint("Error: \{error_message(e)}\n")
              return 1
            }
          }
        None => default_terminal_formatter(options)
      }
  }
  // LaTeX `escapeinside`: collect escaped text before the language lexer
  let lexer = match options.get("escapeinside") {
    Some(esc) if esc.length() == 2 && fmter.name() == "LaTeX" =>
      @formatters.latex_embedded_lexer(
        esc.unsafe_substring(start=0, end=1),
        esc.unsafe_substring(start=1, end=2),
        lexer,
      )
    _ => lexer
  }
  if !args.stream {
    let out = @formatters.highlight(code, lexer, fmter)
    write_aux_files(fmter, args.output)
    match args.output {
      Some(outfn) =>
        @fs.write_file(outfn, out, permission=0o644) catch {
          e => {
            eprint(
              "Error: cannot open outfile: \{os_error_message(e, outfn)}\n",
            )
            return 1
          }
        }
      None => print(out)
    }
    return 0
  }
  // -s: line by line
  let buffered = StringBuilder()
  while @stdio.stdin.read_until("\n") is Some(line) {
    let out = fmter.format(lexer.get_tokens(line + "\n"))
    match args.output {
      Some(_) => buffered.write_string(out)
      None => print(out)
    }
  }
  match args.output {
    Some(outfn) => @fs.write_file(outfn, buffered.to_string())
    None => ()
  }
  0
}

///|
/// Writes side files of a formatter (the HTML `cssfile`), relative to the
/// output file's directory like Python's `HtmlFormatter`.
async fn write_aux_files(
  fmter : @formatters.Formatter,
  output : String?,
) -> Unit {
  for aux in fmter.aux_files() {
    let path = if aux.path.has_prefix("/") {
      aux.path
    } else {
      match output {
        Some(outfn) =>
          match outfn.rev_find("/") {
            Some(i) => outfn.unsafe_substring(start=0, end=i + 1) + aux.path
            None => aux.path
          }
        None => {
          eprint(
            "Note: Cannot determine output file name, using current directory as base for the CSS file name\n",
          )
          aux.path
        }
      }
    }
    if aux.noclobber && @fs.exists(path) {
      continue
    }
    @fs.write_file(path, aux.contents, permission=0o644)
  }
}

///|
/// The formatter used for terminal output when none is given: true color,
/// 256 colors or 16 colors depending on `COLORTERM`/`TERM`.
fn default_terminal_formatter(
  options : Map[String, String],
) -> @formatters.Formatter raise {
  let colorterm = @env.get_env_var("COLORTERM").unwrap_or("")
  let term = @env.get_env_var("TERM").unwrap_or("")
  let name = if colorterm == "truecolor" || colorterm == "24bit" {
    "terminal16m"
  } else if term.contains("256") {
    "terminal256"
  } else {
    "terminal"
  }
  @formatters.get_formatter_by_name(name, options~)
}

///|
/// The system message of an `OSError` ("No such file or directory").
fn os_message(e : @os_error.OSError) -> String {
  let s = e.to_string()
  let msg = match s.rev_find(": ") {
    Some(i) => s.unsafe_substring(start=i + 2, end=s.length())
    None => s
  }
  // `to_string` renders `OSError("context: message")`
  if msg.has_suffix("\")") {
    msg.unsafe_substring(start=0, end=msg.length() - 2)
  } else {
    msg
  }
}
