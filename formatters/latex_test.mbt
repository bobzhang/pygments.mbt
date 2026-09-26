// Ports of tests/test_latex_formatter.py (running `latex` on the output is
// not ported).

///|
test "latex correct output" {
  let tokens = @lexers.get_lexer_by_name("python").get_tokens(
    "def f(x):\n    return x  # comment\n",
  )
  let out = @formatters.LatexFormatter::new(options={ "nowrap": "True" }).format(
    tokens,
  )
  assert_true(!out.contains("\\begin{Verbatim}"))
  assert_true(!out.contains("\\end{Verbatim}"))
}

///|
test "latex embedded lexer" {
  let lexer = @formatters.latex_embedded_lexer(
    "|",
    "|",
    @lexers.get_lexer_by_name("pycon"),
  )
  let src =
    #|>>> x = 1
    #|>>> y = mul(x, |$z^2$|)  # these |pipes| are untouched
    #|>>> y
    #||$1 + z^2$|
  let got = lexer.get_tokens(src).map(t => "\{t.0} \{@pystr.repr(t.1)}")
  inspect(
    got.join("\n"),
    content=(
      #|Token.Generic.Prompt '>>> '
      #|Token.Name 'x'
      #|Token.Text ' '
      #|Token.Operator '='
      #|Token.Text ' '
      #|Token.Literal.Number.Integer '1'
      #|Token.Text.Whitespace '\n'
      #|Token.Generic.Prompt '>>> '
      #|Token.Name 'y'
      #|Token.Text ' '
      #|Token.Operator '='
      #|Token.Text ' '
      #|Token.Name 'mul'
      #|Token.Punctuation '('
      #|Token.Name 'x'
      #|Token.Punctuation ','
      #|Token.Text ' '
      #|Token.Escape '$z^2$'
      #|Token.Punctuation ')'
      #|Token.Text '  '
      #|Token.Comment.Single '# these |pipes| are untouched'
      #|Token.Text.Whitespace '\n'
      #|Token.Generic.Prompt '>>> '
      #|Token.Name 'y'
      #|Token.Text.Whitespace '\n'
      #|Token.Escape '$1 + z^2$'
      #|Token.Generic.Output '\n'
    ),
  )
}

///|
test "latex embedded lexer inherits options" {
  let inner = @lexers.get_lexer_by_name("text", options={ "stripnl": "False" })
  let wrapped = @formatters.latex_embedded_lexer("|", "|", inner)
  assert_eq(wrapped.stripnl, false)
  let src = "\nLINE\n"
  assert_eq(wrapped.get_tokens(src), inner.get_tokens(src))
  assert_true(wrapped.get_tokens(src)[0].1.has_prefix("\n"))
  let explicit = @formatters.latex_embedded_lexer("|", "|", inner, options={
    "stripnl": "True",
  })
  assert_eq(explicit.stripnl, true)
}
