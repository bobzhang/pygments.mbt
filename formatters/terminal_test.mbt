// Ports of tests/test_terminal_formatter.py and tests/test_irc_formatter.py.

///|
let demo_text : String =
  #|-- comment
  #|select
  #|* from bar;
  #|

///|
fn demo_tokens() -> Array[(@token.TokenType, String)] raise {
  @lexers.get_lexer_by_name("plpgsql").get_tokens(demo_text)
}

///|
/// `re.sub(r'\x1b[\w\W]*?m', '', s)`.
fn strip_ansi(s : String) -> String {
  let buf = StringBuilder()
  let mut in_esc = false
  for c in s {
    if in_esc {
      if c == 'm' {
        in_esc = false
      }
    } else if c == '\u{1b}' {
      in_esc = true
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn count_newlines(s : String) -> Int {
  s.iter().filter(c => c == '\n').count()
}

///|
test "reasonable output" {
  let plain = strip_ansi(@formatters.terminal_formatter().format(demo_tokens()))
  assert_eq(count_newlines(demo_text), count_newlines(plain))
  let want = @pystr.splitlines(demo_text)
  let got = @pystr.splitlines(plain)
  for i in 0..<want.length() {
    assert_eq(want[i], got[i])
  }
}

///|
test "reasonable output lineno" {
  let plain = strip_ansi(
    @formatters.terminal_formatter(options={ "linenos": "True" }).format(
      demo_tokens(),
    ),
  )
  assert_eq(count_newlines(demo_text) + 1, count_newlines(plain))
  let want = @pystr.splitlines(demo_text)
  let got = @pystr.splitlines(plain)
  for i in 0..<want.length() {
    assert_true(got[i].contains(want[i]))
  }
}

///|
fn my_style() -> @styles.Style raise {
  @styles.Style::new([
    (@token.comment, "ansibrightblack"),
    (@token.string, "ansibrightblue bg:ansired"),
    (@token.number, "ansibrightgreen bg:ansigreen"),
    (@token.number_hex, "ansigreen bg:ansibrightred"),
    (@token.other, "#3366AA"),
  ])
}

///|
let terminal_code : String =
  #|
  #|# this should be a comment
  #|print("Hello World")
  #|async def function(a,b,c, *d, **kwarg:Bool)->Bool:
  #|    pass
  #|    return 123, 0xb3e3
  #|

///|
test "style html" {
  let style = @formatters.HtmlFormatter::new(style=my_style()).get_style_defs()
  assert_true(style.contains("#555"))
  assert_true(style.contains("36A"))
}

///|
test "others work" {
  let lx = @lexers.get_lexer_by_name("python3")
  ignore(
    @formatters.highlight(
      terminal_code,
      lx,
      @formatters.LatexFormatter::new(style=my_style()).to_formatter(),
    ),
  )
  ignore(
    @formatters.highlight(
      terminal_code,
      lx,
      @formatters.HtmlFormatter::new(style=my_style()).to_formatter(),
    ),
  )
}

///|
test "256 escape sequences" {
  let termtest = (x : String) => {
    @formatters.highlight(
      x,
      @lexers.get_lexer_by_name("python3"),
      @formatters.terminal256_formatter(style=my_style()),
    )
  }
  assert_true(termtest("0x123").contains("32;101"))
  assert_true(termtest("123").contains("92;42"))
  assert_true(termtest("#comment").contains("90"))
  assert_true(termtest("\"String\"").contains("94;41"))
}

///|
test "irc correct output" {
  let tokens = @lexers.get_lexer_by_name("python").get_tokens("lambda x: 123")
  assert_eq(
    @formatters.irc_formatter().format(tokens),
    "\u{03}02lambda\u{03} x: \u{03}02123\u{03}\n",
  )
}

///|
test "irc linecount output" {
  let tokens = @lexers.get_lexer_by_name("python").get_tokens(
    "from \\\n\\\n    os import  path\n",
  )
  assert_eq(
    @formatters.irc_formatter(options={ "linenos": "True" }).format(tokens),
    "0001: \u{03}02from\u{03}\u{03}15 \\\u{03}\n0002: \u{03}15\\\u{03}\n0003: \u{03}15    \u{03}\u{1d}\u{03}10os\u{03}\u{1d}\u{03}15 \u{03}\u{03}02import\u{03}  path\n0004: ",
  )
}
