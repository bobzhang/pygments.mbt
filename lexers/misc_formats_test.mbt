///|
fn tokens_of(lx : @lexer.Lexer, text : String) -> String raise {
  lx.get_tokens(text).map(t => "\{t.0} \{t.1.escape()}").join("\n")
}

///|
test "typst start option selects the initial state" {
  let lx = @lexers.get_lexer_by_name("typst", options={ "start": "math" })
  inspect(
    tokens_of(lx, "a + b"),
    content=(
      #|Token.Name.Variable "a"
      #|Token.Text.Whitespace " "
      #|Token.Operator "+"
      #|Token.Text.Whitespace " "
      #|Token.Name.Variable "b"
      #|Token.Text.Whitespace "\n"
    ),
  )
}

///|
test "http body is lexed by content type" {
  let lx = @lexers.get_lexer_by_name("http")
  inspect(
    tokens_of(lx, "HTTP/1.1 200 OK\nContent-Type: application/json\n\n[1]"),
    content=(
      #|Token.Keyword.Reserved "HTTP"
      #|Token.Operator "/"
      #|Token.Literal.Number "1.1"
      #|Token.Text " "
      #|Token.Literal.Number "200"
      #|Token.Text " "
      #|Token.Name.Exception "OK"
      #|Token.Text "\n"
      #|Token.Name.Attribute "Content-Type"
      #|Token.Text ""
      #|Token.Operator ":"
      #|Token.Text " "
      #|Token.Literal "application/json"
      #|Token.Text "\n"
      #|Token.Text "\n"
      #|Token.Punctuation "["
      #|Token.Literal.Number.Integer "1"
      #|Token.Punctuation "]"
      #|Token.Text.Whitespace "\n"
    ),
  )
}

///|
test "email highlight-X-header option" {
  let lx = @lexers.get_lexer_by_name("email", options={
    "highlight-X-header": "true",
  })
  inspect(
    tokens_of(lx, "X-Mailer: Foo 1.0\n\nbody\n"),
    content=(
      #|Token.Name.Tag "X-Mailer:"
      #|Token.Text.Whitespace " "
      #|Token.Text "F"
      #|Token.Text "o"
      #|Token.Text "o"
      #|Token.Text.Whitespace " "
      #|Token.Text "1"
      #|Token.Text "."
      #|Token.Text "0"
      #|Token.Text.Whitespace "\n"
      #|Token.Text.Whitespace "\n"
      #|Token.Text "body\n"
    ),
  )
}

///|
test "markdown handlecodeblocks option" {
  let lx = @lexers.get_lexer_by_name("md", options={
    "handlecodeblocks": "false",
  })
  inspect(
    tokens_of(lx, "```python\nx = 1\n```\n"),
    content=(
      #|Token.Literal.String.Backtick "```"
      #|Token.Literal.String.Backtick "python"
      #|Token.Text.Whitespace "\n"
      #|Token.Literal.String "x = 1\n"
      #|Token.Literal.String.Backtick "```\n"
    ),
  )
}

///|
test "inform7 i6t option" {
  let lx = @lexers.get_lexer_by_name("inform7", options={ "i6t": "+i6t-inline" })
  inspect(
    tokens_of(lx, "(- rtrue; -)"),
    content=(
      #|Token.Punctuation "(-"
      #|Token.Text " "
      #|Token.Name.Class "rtrue"
      #|Token.Error ";"
      #|Token.Text " "
      #|Token.Punctuation "-)"
      #|Token.Text "\n"
    ),
  )
}
