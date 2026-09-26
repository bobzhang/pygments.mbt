///|
fn templates_test_dump(toks : Array[(@token.TokenType, String)]) -> String {
  toks.map(t => "\{t.0}:\{t.1.escape()}").join("\n")
}

///|
test "erb tags" {
  let lx = @lexers.erb_lexer()
  inspect(
    templates_test_dump(lx.get_tokens("a<%# c %>b<%% x\n% y\n")),
    content=(
      #|Token.Other:"a"
      #|Token.Comment.Preproc:"<%#"
      #|Token.Comment:" c "
      #|Token.Comment.Preproc:"%>"
      #|Token.Other:"b"
      #|Token.Other:"<%%"
      #|Token.Other:" x\n"
      #|Token.Comment.Preproc:"%"
      #|Token.Text.Whitespace:" "
      #|Token.Name:"y"
      #|Token.Other:"\n"
    ),
  )
}

///|
test "sass indented comment block" {
  let lx = @lexers.sass_lexer()
  inspect(
    templates_test_dump(lx.get_tokens(".a\n  //c\n    d\n  b: c\n")),
    content=(
      #|Token.Text.Whitespace:""
      #|Token.Name.Class:"."
      #|Token.Name.Class:"a"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text.Whitespace:"  "
      #|Token.Comment.Single:"//c"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text.Whitespace:"    "
      #|Token.Comment.Single:"d"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text.Whitespace:"  "
      #|Token.Name.Attribute:""
      #|Token.Name.Attribute:"b"
      #|Token.Operator:":"
      #|Token.Text.Whitespace:" "
      #|Token.Name:"c"
      #|Token.Text.Whitespace:"\n"
      #|Token.Text.Whitespace:""
    ),
  )
}
