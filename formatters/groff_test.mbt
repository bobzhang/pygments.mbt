// Ports of tests/test_groff_formatter.py and
// tests/test_pangomarkup_formatter.py. The expected groff documents end in
// "\n\n.fi": that is what the pinned Python produces (the upstream test
// strings show a single newline and fail against the pinned checkout).

///|
test "groff basic" {
  let code =
    #|
    #|for it in that:
    #|    do(it)
    #|import this
    #|
  let expected =
    #|.defcolor 000080 rgb #000080
    #|.defcolor 0000FF rgb #0000FF
    #|.defcolor 0044DD rgb #0044DD
    #|.defcolor 008000 rgb #008000
    #|.defcolor 008400 rgb #008400
    #|.defcolor 19177C rgb #19177C
    #|.defcolor 3D7B7B rgb #3D7B7B
    #|.defcolor 666666 rgb #666666
    #|.defcolor 687822 rgb #687822
    #|.defcolor 717171 rgb #717171
    #|.defcolor 767600 rgb #767600
    #|.defcolor 800080 rgb #800080
    #|.defcolor 880000 rgb #880000
    #|.defcolor 9C6500 rgb #9C6500
    #|.defcolor A00000 rgb #A00000
    #|.defcolor A45A77 rgb #A45A77
    #|.defcolor AA22FF rgb #AA22FF
    #|.defcolor AA5D1F rgb #AA5D1F
    #|.defcolor B00040 rgb #B00040
    #|.defcolor BA2121 rgb #BA2121
    #|.defcolor CB3F38 rgb #CB3F38
    #|.defcolor E40000 rgb #E40000
    #|.defcolor bbbbbb rgb #bbbbbb
    #|.nf
    #|\f[CR]
    #|\m[008000]\f[CB]for\f[CR]\m[] it \m[AA22FF]\f[CB]in\f[CR]\m[] that:
    #|    do(it)
    #|\m[008000]\f[CB]import\f[CR]\m[]\m[bbbbbb] \m[]\m[0000FF]\f[CB]this\f[CR]\m[]
    #|
    #|.fi
  assert_eq(
    @formatters.highlight(
      code,
      @lexers.get_lexer_by_name("python"),
      @formatters.groff_formatter(),
    ),
    expected,
  )
}

///|
test "groff inheritance of custom tokens" {
  let style = @styles.Style::new([(@token.name, "bold")])
  let tokens = [
    (@token.name, "a"),
    (@token.name.sub("Custom"), "b"),
    (@token.whitespace, "\n"),
  ]
  assert_eq(
    @formatters.groff_formatter(style~).format(tokens),
    (
      #|.nf
      #|\f[CR]
      #|\f[CB]a\f[CR]\f[CB]b\f[CR]
      #|
      #|.fi
    ),
  )
}

///|
test "groff wrap does not duplicate characters" {
  let style = @styles.Style::new([])
  let f = @formatters.groff_formatter(options={ "wrap": "4" }, style~)
  assert_eq(
    f.format([(@token.text, "abcdefghij"), (@token.text, "123456\n")]),
    ".nf\n\\f[CR]\nabcd\nefgh\nij1234\n56\n\n.fi",
  )
}

///|
test "pango correct output" {
  let input =
    #|
    #|function foobar(a, b) {
    #|   if (a > b) {
    #|      return a & b;
    #|   }
    #|   if (a < b) {
    #|      return true;
    #|   }
    #|   console.log("single quote ' and double quote \"")
    #|   console.log('single quote \' and double quote "')
    #|   // comment with äöü ç
    #|}
    #|
  let output =
    #|<tt><span fgcolor="#"><b>function</b></span><span fgcolor="#"> </span>foobar(a,<span fgcolor="#"> </span>b)<span fgcolor="#"> </span>{<span fgcolor="#">
    #|   </span><span fgcolor="#"><b>if</b></span><span fgcolor="#"> </span>(a<span fgcolor="#"> </span><span fgcolor="#">></span><span fgcolor="#"> </span>b)<span fgcolor="#"> </span>{<span fgcolor="#">
    #|      </span><span fgcolor="#"><b>return</b></span><span fgcolor="#"> </span>a<span fgcolor="#"> </span><span fgcolor="#">&amp;</span><span fgcolor="#"> </span>b;<span fgcolor="#">
    #|   </span>}<span fgcolor="#">
    #|   </span><span fgcolor="#"><b>if</b></span><span fgcolor="#"> </span>(a<span fgcolor="#"> </span><span fgcolor="#">&lt;</span><span fgcolor="#"> </span>b)<span fgcolor="#"> </span>{<span fgcolor="#">
    #|      </span><span fgcolor="#"><b>return</b></span><span fgcolor="#"> </span><span fgcolor="#"><b>true</b></span>;<span fgcolor="#">
    #|   </span>}<span fgcolor="#">
    #|   </span>console.log(<span fgcolor="#">"single quote ' and double quote \""</span>)<span fgcolor="#">
    #|   </span>console.log(<span fgcolor="#">'single quote \' and double quote "'</span>)<span fgcolor="#">
    #|   </span><span fgcolor="#"><i>// comment with äöü ç</i></span><span fgcolor="#">
    #|</span>}<span fgcolor="#">
    #|</span></tt>
  let markup = @formatters.highlight(
    input,
    @lexers.get_lexer_by_name("javascript"),
    @formatters.pango_markup_formatter(),
  )
  // re.sub('<span fgcolor="#[^"]{6}">', '<span fgcolor="#">', markup)
  let prefix = "<span fgcolor=\"#"
  let buf = StringBuilder()
  let mut rest = markup
  while rest.find(prefix) is Some(i) {
    buf.write_string(rest.unsafe_substring(start=0, end=i) + prefix)
    rest = rest.unsafe_substring(
      start=i + prefix.length() + 6,
      end=rest.length(),
    )
  }
  buf.write_string(rest)
  assert_eq(buf.to_string(), output)
}
