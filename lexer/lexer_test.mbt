///|
fn tok(index : Int, value : String) -> @lexer.Token {
  { index, ttype: @token.text, value, }
}

///|
test "do_insertions splits tokens at insertion points" {
  let ins : Array[(Int, Array[@lexer.Token])] = [
    (2, [{ index: 0, ttype: @token.generic_prompt, value: ">>> ", }]),
  ]
  let out = @lexer.do_insertions(ins, [tok(0, "abcd"), tok(4, "ef")])
  inspect(
    out.map(t => "\{t.index}:\{t.value}").join(" "),
    content="0:ab 2:>>>  6:cd 8:ef",
  )
  // insertion after the end of the stream
  let out2 = @lexer.do_insertions(
    [(10, [{ index: 0, ttype: @token.generic_prompt, value: "$ ", }])],
    [tok(0, "ab")],
  )
  inspect(out2.map(t => "\{t.index}:\{t.value}").join(" "), content="0:ab 2:$ ")
}

///|
test "option accessors follow pygments.util" {
  let opts : @lexer.Options = Map::from_array([
    ("a", "Yes"),
    ("b", "off"),
    ("n", " 4 "),
    ("l", " x  y\tz "),
  ])
  inspect(@lexer.get_bool_opt(opts, "a", false), content="true")
  inspect(@lexer.get_bool_opt(opts, "b", true), content="false")
  inspect(@lexer.get_bool_opt(opts, "missing", true), content="true")
  inspect(@lexer.get_int_opt(opts, "n", 0), content="4")
  inspect(@lexer.get_list_opt(opts, "l", []).join(","), content="x,y,z")
  try @lexer.get_bool_opt(opts, "n", false) catch {
    OptionError(msg) => inspect(msg.has_prefix("Invalid value"), content="true")
  } noraise {
    _ => fail("expected OptionError")
  }
}

///|
test "expand_tabs and py_slice" {
  inspect(
    @lexer.expand_tabs("a\tb\n\tc", 4).escape(),
    content="\"a   b\\n    c\"",
  )
  inspect(@lexer.py_slice("hello", 1, -1), content="ell")
  inspect(@lexer.py_slice("hello", 3, 99), content="lo")
  inspect(@lexer.py_slice("hello", 4, 2), content="")
}

///|
test "shebang and doctype helpers" {
  inspect(
    @lexer.shebang_matches("#!/usr/bin/env python3\n", "pythonw?(3(\\.\\d)?)?"),
    content="true",
  )
  inspect(
    @lexer.shebang_matches("#!/usr/bin/python-ruby", "python(2\\.\\d)?"),
    content="false",
  )
  inspect(
    @lexer.html_doctype_matches("<!DOCTYPE html>\n<html></html>"),
    content="true",
  )
  inspect(@lexer.looks_like_xml("<?xml version=\"1.0\"?><a/>"), content="true")
}

///|
/// A one-rule lexer: `a` is `Text`.
fn tiny_lexer(extended : Bool) -> (@lexer.Lexer, @lexer.RegexDef) raise {
  let def = @lexer.RegexDef::new(
    "Tiny",
    ["root"],
    [@lexer.Rule::new("a", 0, Emit(@token.text), None)],
    [[0]],
    extended~,
  )
  let info : @lexer.LexerInfo = {
    class_name: "TinyLexer",
    name: "Tiny",
    aliases: [],
    filenames: [],
    alias_filenames: [],
    mimetypes: [],
    priority: 0.0,
    url: "",
    version_added: "",
    analyse_text: @lexer.no_analyse,
    doc: "",
  }
  fn make(opts : @lexer.Options) -> @lexer.Lexer raise {
    @lexer.Lexer::new(info, opts, make, (lx, text, stack) => {
      @lexer.run_regex(lx, def, text, stack)
    })
  }

  (make(Map([])), def)
}

///|
fn run_ctx(ctx : @lexer.Ctx) -> String raise {
  @lexer.run_context(ctx)
  ctx.out.map(t => "\{t.index}:\{t.ttype}:\{t.value.escape()}").join(" ")
}

///|
test "context positions are clamped like Python (pos < 0, end > len)" {
  for extended in [true, false] {
    let (lx, def) = tiny_lexer(extended)
    // Python: [(-1, Text, 'a')]
    inspect(
      run_ctx(@lexer.Ctx::new(lx, def, "a", pos=-1)),
      content="-1:Token.Text:\"a\"",
    )
  }
  let (lx, def) = tiny_lexer(true)
  // `end` beyond the text: the loop stops at the end of the text
  inspect(
    run_ctx(@lexer.Ctx::new(lx, def, "ab", end=10)),
    content="0:Token.Text:\"a\" 1:Token.Error:\"b\"",
  )
  // no rule matches at a negative position: Python reads text[-1]
  inspect(
    run_ctx(@lexer.Ctx::new(lx, def, "xb", pos=-1)),
    content="-1:Token.Error:\"b\" 0:Token.Error:\"x\" 1:Token.Error:\"b\"",
  )
}
