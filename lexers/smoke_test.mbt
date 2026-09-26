///|
test "python smoke" {
  let lx = @lexers.python_lexer()
  let toks = lx.get_tokens("def f(x):\n    return x + 1  # hi\n")
  inspect(
    toks.map(t => "\{t.0}:\{t.1.escape()}").join("\n"),
    content=(
      #|Token.Keyword:"def"
      #|Token.Text.Whitespace:" "
      #|Token.Name.Function:"f"
      #|Token.Punctuation:"("
      #|Token.Name:"x"
      #|Token.Punctuation:")"
      #|Token.Punctuation:":"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text:"    "
      #|Token.Keyword:"return"
      #|Token.Text:" "
      #|Token.Name:"x"
      #|Token.Text:" "
      #|Token.Operator:"+"
      #|Token.Text:" "
      #|Token.Literal.Number.Integer:"1"
      #|Token.Text:"  "
      #|Token.Comment.Single:"# hi"
      #|Token.Text.Whitespace:"\n"
    ),
  )
}
