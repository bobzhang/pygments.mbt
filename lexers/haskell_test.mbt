///|
fn haskell_test_render(toks : Array[(@token.TokenType, String)]) -> String {
  toks.map(t => "\{t.0}:\{t.1.escape()}").join("\n")
}

///|
test "literate idris bird style" {
  let lx = @lexers.literate_idris_lexer()
  inspect(
    haskell_test_render(lx.get_tokens("> main : IO ()\ntext\n")),
    content=(
      #|Token.Comment.Special:"> "
      #|Token.Name.Function:"main"
      #|Token.Text.Whitespace:" "
      #|Token.Operator.Word:":"
      #|Token.Text.Whitespace:" "
      #|Token.Keyword.Type:"IO"
      #|Token.Text.Whitespace:" "
      #|Token.Operator.Word:"()"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text:"text\n"
    ),
  )
}

///|
test "cryptol extra keywords" {
  let lx = @lexers.cryptol_lexer()
  inspect(
    haskell_test_render(lx.get_tokens("f x = join x\n")),
    content=(
      #|Token.Name.Function:"f"
      #|Token.Text.Whitespace:" "
      #|Token.Name:"x"
      #|Token.Text.Whitespace:" "
      #|Token.Operator.Word:"="
      #|Token.Text.Whitespace:" "
      #|Token.Name.Builtin:"join"
      #|Token.Text.Whitespace:" "
      #|Token.Name:"x"
      #|Token.Text.Whitespace:"\n"
    ),
  )
}
