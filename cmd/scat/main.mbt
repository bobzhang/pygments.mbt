///|
/// `scat`: `cat` with syntax highlighting.
///
///     scat [-l LANG] [-s STYLE] [-n] [-p] [FILE ...]
///
/// The language is taken from `-l`, else from the file name, else guessed
/// from the contents, else plain text. Without `-s` the output uses the
/// terminal's own 16-color palette (readable on dark and light themes); with
/// `-s STYLE` it uses 24-bit color when `COLORTERM` says so, 256 colors
/// otherwise.
async fn main {
  let code = run(@env.args()[1:].to_owned()) catch {
    e => {
      @stdio.stderr.write("scat: \{error_text(e)}\n")
      1
    }
  }
  @sys.exit(code)
}

///|
let usage : String =
  #|usage: scat [-l LANG] [-s STYLE] [-n] [-p] [--light] [FILE ...]
  #|
  #|Print files with syntax highlighting (standard input if no FILE or FILE is -).
  #|
  #|  -l LANG     language (a lexer alias, e.g. python, rust, moonbit)
  #|  -s STYLE    color style (e.g. monokai, dracula, github-dark); see --styles
  #|  -n          number lines
  #|  -p          plain: no colors
  #|  --light     colors for a light terminal background (without -s)
  #|  --langs     list language aliases
  #|  --styles    list styles
  #|  -h, --help  show this help
  #|

///|
priv struct Config {
  mut lang : String?
  mut style : String?
  mut numbers : Bool
  mut plain : Bool
  mut light : Bool
  files : Array[String]
}

///|
fn error_text(e : Error) -> String {
  match e {
    @lexers.ClassNotFound(msg) => msg
    @formatters.ClassNotFound(msg) => msg
    @styles.ClassNotFound(_) => "unknown style (see scat --styles)"
    @os_error.OSError(_) as e => os_message(e)
    _ => Repr(e).to_string()
  }
}

///|
async fn run(argv : Array[String]) -> Int {
  let cfg : Config = {
    lang: None,
    style: None,
    numbers: false,
    plain: false,
    light: false,
    files: [],
  }
  let mut i = 0
  while i < argv.length() {
    let a = argv[i]
    i += 1
    match a {
      "-h" | "--help" => {
        @stdio.stdout.write(usage)
        return 0
      }
      "--langs" => {
        let names = @lexers.all_lexers
          .filter(e => !e.0.aliases.is_empty())
          .map(e => "\{e.0.aliases.join(", ")}: \{e.0.name}")
        names.sort()
        @stdio.stdout.write(names.join("\n") + "\n")
        return 0
      }
      "--styles" => {
        @stdio.stdout.write(@styles.get_all_styles().join("\n") + "\n")
        return 0
      }
      "-n" => cfg.numbers = true
      "-p" => cfg.plain = true
      "--light" => cfg.light = true
      "-l" | "-s" => {
        if i >= argv.length() {
          @stdio.stderr.write("scat: option \{a} needs an argument\n" + usage)
          return 2
        }
        if a == "-l" {
          cfg.lang = Some(argv[i])
        } else {
          cfg.style = Some(argv[i])
        }
        i += 1
      }
      _ =>
        if a.has_prefix("-") && a != "-" {
          @stdio.stderr.write("scat: unknown option \{a}\n" + usage)
          return 2
        } else {
          cfg.files.push(a)
        }
    }
  }
  if cfg.files.is_empty() {
    cfg.files.push("-")
  }
  let formatter = make_formatter(cfg)
  let mut status = 0
  for file in cfg.files {
    let text = if file == "-" {
      decode(@stdio.stdin.read_all().binary())
    } else {
      decode(
        (@fs.read_file(file) catch {
          e => {
            @stdio.stderr.write("scat: \{file}: \{error_text(e)}\n")
            status = 1
            continue
          }
        }).binary(),
      )
    }
    let lexer = pick_lexer(cfg.lang, file, text)
    @stdio.stdout.write(formatter.format(lexer.get_tokens(text)))
  }
  status
}

///|
/// The lexer for `file`: `-l`, then the file name, then a content guess,
/// then plain text.
fn pick_lexer(
  lang : String?,
  file : String,
  text : String,
) -> @lexer.Lexer raise {
  let opts : @lexer.Options = Map::from_array([("stripnl", "False")])
  match lang {
    Some(l) => return @lexers.get_lexer_by_name(l, options=opts)
    None => ()
  }
  if file != "-" {
    match @lexers.find_lexer_class_for_filename(file, code=text) {
      Some(entry) => return (entry.1)(opts)
      None => ()
    }
  }
  @lexers.guess_lexer(text, options=opts) catch {
    _ => @lexers.text_lexer(options=opts)
  }
}

///|
fn make_formatter(cfg : Config) -> @formatters.Formatter raise {
  let opts : Map[String, String] = Map([])
  if cfg.numbers {
    opts["linenos"] = "True"
  }
  if cfg.plain {
    return @formatters.get_formatter_by_name("text", options=opts)
  }
  match cfg.style {
    None => {
      if cfg.light {
        opts["bg"] = "light"
      }
      @formatters.get_formatter_by_name("terminal", options=opts)
    }
    Some(style) => {
      opts["style"] = style
      let colorterm = @env.get_env_var("COLORTERM").unwrap_or("")
      let name = if colorterm == "truecolor" || colorterm == "24bit" {
        "terminal16m"
      } else {
        "terminal256"
      }
      @formatters.get_formatter_by_name(name, options=opts)
    }
  }
}

///|
/// UTF-8 (dropping a BOM), falling back to Latin-1.
fn decode(data : Bytes) -> String {
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
