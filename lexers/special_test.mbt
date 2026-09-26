///|
test "raw token lexer" {
  let lx = @lexers.raw_token_lexer()
  let input = "Token.Name\t'foo'\nToken.Text\t\"a\\nb\\x41\\u00e9\" u'c'\nToken.bad\t'x'\nToken.Literal.String\t'\\\\'\nnotab\nToken.Number\t12\n"
  inspect(
    lx.get_tokens(input).map(t => "\{t.0}:\{t.1.escape()}").join("\n"),
    content=(
      #|Token.Name:"foo"
      #|Token.Text:"a\nbAéc"
      #|Token.Error:"Token.bad\t'x'\n"
      #|Token.Literal.String:"\\"
      #|Token.Error:"notab\n"
      #|Token.Error:"Token.Number\t12\n"
    ),
  )
}
