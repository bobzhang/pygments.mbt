///|
fn dump_tokens(lx : @lexer.Lexer, text : String) -> String raise {
  lx.get_tokens(text).map(t => "\{t.0}:\{t.1.escape()}").join("\n")
}

///|
test "lua disabled_modules" {
  let lx = @lexers.lua_lexer(options={ "disabled_modules": "string" })
  inspect(
    dump_tokens(lx, "print(string.len(x))\n"),
    content=(
      #|Token.Name.Builtin:"print"
      #|Token.Punctuation:"("
      #|Token.Name:"string"
      #|Token.Punctuation:"."
      #|Token.Name:"len"
      #|Token.Punctuation:"("
      #|Token.Name.Variable:"x"
      #|Token.Punctuation:"))"
      #|Token.Text.Whitespace:"\n"
    ),
  )
}

///|
test "php startinline" {
  let lx = @lexers.php_lexer(options={ "startinline": "True" })
  inspect(
    dump_tokens(lx, "echo strlen($a);\n"),
    content=(
      #|Token.Keyword:"echo"
      #|Token.Text:" "
      #|Token.Name.Builtin:"strlen"
      #|Token.Punctuation:"("
      #|Token.Name.Variable:"$a"
      #|Token.Punctuation:");"
      #|Token.Text:"\n"
    ),
  )
}

///|
test "luau builtins" {
  let lx = @lexers.luau_lexer(options={ "include_roblox_builtins": "True" })
  inspect(
    dump_tokens(lx, "local x = game.Workspace.Part\nmath.floor(y)\n"),
    content=(
      #|Token.Keyword.Declaration:"local"
      #|Token.Text.Whitespace:" "
      #|Token.Name.Variable:"x"
      #|Token.Text.Whitespace:" "
      #|Token.Operator:"="
      #|Token.Text.Whitespace:" "
      #|Token.Name.Variable:"game"
      #|Token.Punctuation:"."
      #|Token.Name.Variable:"Workspace"
      #|Token.Punctuation:"."
      #|Token.Name.Variable:"Part"
      #|Token.Text.Whitespace:"\n"
      #|Token.Name.Builtin:"math"
      #|Token.Punctuation:"."
      #|Token.Name.Function:"floor"
      #|Token.Punctuation:"("
      #|Token.Name.Variable:"y"
      #|Token.Punctuation:")"
      #|Token.Text.Whitespace:"\n"
    ),
  )
}

///|
test "moonscript dots" {
  let lx = @lexers.moon_script_lexer()
  inspect(
    dump_tokens(lx, "x = string.len a.b\n"),
    content=(
      #|Token.Name:"x"
      #|Token.Text:" "
      #|Token.Operator:"="
      #|Token.Text:" "
      #|Token.Name.Builtin:"string.len"
      #|Token.Text:" "
      #|Token.Name:"a"
      #|Token.Operator:"."
      #|Token.Name:"b"
      #|Token.Text.Whitespace:"\n"
    ),
  )
}
