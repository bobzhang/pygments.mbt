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
