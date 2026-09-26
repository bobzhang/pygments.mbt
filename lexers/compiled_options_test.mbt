// Option handling of hand-written lexer parts, checked against Python.

///|
test "options csharp 0" {
  let lx = @lexers.get_lexer_by_name(
    "csharp",
    options=Map::from_array([("unicodelevel", "none")]),
  )
  let got = lx
    .get_tokens("class \u{dc}n\u{ef} { int \u{e4} = 1; }\n")
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "class"),
    ("Token.Text.Whitespace", " "),
    ("Token.Error", "\u{dc}"),
    ("Token.Name", "n\u{ef}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "{"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword.Type", "int"),
    ("Token.Text.Whitespace", " "),
    ("Token.Error", "\u{e4}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Operator", "="),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Integer", "1"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "}"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options csharp 1" {
  let lx = @lexers.get_lexer_by_name(
    "csharp",
    options=Map::from_array([("unicodelevel", "full")]),
  )
  let got = lx
    .get_tokens("class \u{dc}n\u{ef} { int \u{e4} = 1; }\n")
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "class"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Class", "\u{dc}n\u{ef}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "{"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword.Type", "int"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "\u{e4}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Operator", "="),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Integer", "1"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "}"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options nemerle 2" {
  let lx = @lexers.get_lexer_by_name(
    "nemerle",
    options=Map::from_array([("unicodelevel", "none")]),
  )
  let got = lx
    .get_tokens("def \u{e4}\u{f6} = 1;\n")
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "def"),
    ("Token.Text.Whitespace", " "),
    ("Token.Error", "\u{e4}"),
    ("Token.Error", "\u{f6}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "="),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number", "1"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options nemerle 3" {
  let lx = @lexers.get_lexer_by_name(
    "nemerle",
    options=Map::from_array([("unicodelevel", "full")]),
  )
  let got = lx
    .get_tokens("def \u{e4}\u{f6} = 1;\n")
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "def"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "\u{e4}\u{f6}"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "="),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number", "1"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options modula2 4" {
  let lx = @lexers.get_lexer_by_name(
    "modula2",
    options=Map::from_array([("dialect", "m2pim")]),
  )
  let got = lx
    .get_tokens(
      "MODULE M; (*$foo*) <* bar *> // x\nCONST a = 0x1F; b = 10H; c = 1.0E3; d = 17B;\nVAR x : CARDINAL; y : LONGCARD;\nBEGIN x := a # b; y := BITSET{} END M.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword.Reserved", "MODULE"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Comment.Preproc", "(*$foo*)"),
    ("Token.Text", " "),
    ("Token.Error", "<* bar *>"),
    ("Token.Text", " "),
    ("Token.Operator", "/"),
    ("Token.Operator", "/"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "CONST"),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Error", "0x1F"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Literal.Number.Hex", "10H"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "c"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Literal.Number.Float", "1.0E3"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "d"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Literal.Number.Oct", "17B"),
    ("Token.Punctuation", ";"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "VAR"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "CARDINAL"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name", "LONGCARD"),
    ("Token.Punctuation", ";"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "BEGIN"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "#"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "BITSET"),
    ("Token.Punctuation", "{"),
    ("Token.Punctuation", "}"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "END"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", "."),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options modula2 5" {
  let lx = @lexers.get_lexer_by_name(
    "modula2",
    options=Map::from_array([("dialect", "m2r10")]),
  )
  let got = lx
    .get_tokens(
      "MODULE M; (*$foo*) <* bar *> // x\nCONST a = 0x1F; b = 10H; c = 1.0E3; d = 17B;\nVAR x : CARDINAL; y : LONGCARD;\nBEGIN x := a # b; y := BITSET{} END M.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword.Reserved", "MODULE"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Comment.Multiline", "(*$foo*)"),
    ("Token.Text", " "),
    ("Token.Comment.Preproc", "<* bar *>"),
    ("Token.Text", " "),
    ("Token.Operator", "/"),
    ("Token.Operator", "/"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "CONST"),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Literal.Number.Hex", "0x1F"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Error", "10H"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "c"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Error", "1.0E3"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "d"),
    ("Token.Text", " "),
    ("Token.Operator", "="),
    ("Token.Text", " "),
    ("Token.Error", "17B"),
    ("Token.Punctuation", ";"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "VAR"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "CARDINAL"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "LONGCARD"),
    ("Token.Punctuation", ";"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "BEGIN"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "#"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name.Builtin.Pseudo", "BITSET"),
    ("Token.Punctuation", "{"),
    ("Token.Punctuation", "}"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "END"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", "."),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options modula2 6" {
  let lx = @lexers.get_lexer_by_name(
    "modula2",
    options=Map::from_array([("style", "algol")]),
  )
  let got = lx
    .get_tokens(
      "MODULE M;\nBEGIN IF a # b THEN x := a <= b; y := a >= b END; WriteString(x) END M.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword.Reserved", "module"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", ";"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "begin"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "if"),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "\u{2260}"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "then"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "\u{2264}"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Name", "a"),
    ("Token.Text", " "),
    ("Token.Operator", "\u{2265}"),
    ("Token.Text", " "),
    ("Token.Name", "b"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "end"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "WriteString"),
    ("Token.Punctuation", "("),
    ("Token.Name", "x"),
    ("Token.Punctuation", ")"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "end"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", "."),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options modula2 7" {
  let lx = @lexers.get_lexer_by_name(
    "modula2",
    options=Map::from_array([
      ("treat_stdlib_adts_as_builtins", "False"),
      ("dialect", "m2iso"),
    ]),
  )
  let got = lx
    .get_tokens(
      "(*!m2pim+gm2*)\nMODULE M; IMPORT Strings, STextIO; VAR s : String; BEGIN WriteLn END M.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Comment.Special", "(*!m2pim+gm2*)"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "MODULE"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "IMPORT"),
    ("Token.Text", " "),
    ("Token.Name", "Strings"),
    ("Token.Punctuation", ","),
    ("Token.Text", " "),
    ("Token.Name", "STextIO"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "VAR"),
    ("Token.Text", " "),
    ("Token.Name", "s"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name", "String"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "BEGIN"),
    ("Token.Text", " "),
    ("Token.Name.Function", "WriteLn"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "END"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", "."),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options modula2 8" {
  let lx = @lexers.get_lexer_by_name("modula2", options=Map::from_array([]))
  let got = lx
    .get_tokens(
      "(*!objm2*)\nMODULE M; VAR x : OCTET; BEGIN x := 0u1F; y := 017B; z := 1.0E3 END M.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Comment.Special", "(*!objm2*)"),
    ("Token.Text", "\n"),
    ("Token.Keyword.Reserved", "MODULE"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "VAR"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Punctuation", ":"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "OCTET"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "BEGIN"),
    ("Token.Text", " "),
    ("Token.Name", "x"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Literal.Number.Hex", "0u1F"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "y"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Error", "017B"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "z"),
    ("Token.Text", " "),
    ("Token.Operator", ":="),
    ("Token.Text", " "),
    ("Token.Error", "1.0E3"),
    ("Token.Text", " "),
    ("Token.Keyword.Reserved", "END"),
    ("Token.Text", " "),
    ("Token.Name", "M"),
    ("Token.Punctuation", "."),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options sp 9" {
  let lx = @lexers.get_lexer_by_name(
    "sp",
    options=Map::from_array([("sourcemod", "False")]),
  )
  let got = lx
    .get_tokens(
      "public void OnPluginStart() { Handle h; PrintToServer(\"x\"); }\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "public"),
    ("Token.Text", " "),
    ("Token.Name", "void"),
    ("Token.Text", " "),
    ("Token.Name", "OnPluginStart"),
    ("Token.Punctuation", "("),
    ("Token.Punctuation", ")"),
    ("Token.Text", " "),
    ("Token.Punctuation", "{"),
    ("Token.Text", " "),
    ("Token.Name", "Handle"),
    ("Token.Text", " "),
    ("Token.Name", "h"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name", "PrintToServer"),
    ("Token.Punctuation", "("),
    ("Token.Literal.String", "\""),
    ("Token.Literal.String", "x"),
    ("Token.Literal.String", "\""),
    ("Token.Punctuation", ")"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Punctuation", "}"),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options sp 10" {
  let lx = @lexers.get_lexer_by_name("sp", options=Map::from_array([]))
  let got = lx
    .get_tokens(
      "public void OnPluginStart() { Handle h; PrintToServer(\"x\"); }\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "public"),
    ("Token.Text", " "),
    ("Token.Name", "void"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "OnPluginStart"),
    ("Token.Punctuation", "("),
    ("Token.Punctuation", ")"),
    ("Token.Text", " "),
    ("Token.Punctuation", "{"),
    ("Token.Text", " "),
    ("Token.Keyword.Type", "Handle"),
    ("Token.Text", " "),
    ("Token.Name", "h"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Name.Builtin", "PrintToServer"),
    ("Token.Punctuation", "("),
    ("Token.Literal.String", "\""),
    ("Token.Literal.String", "x"),
    ("Token.Literal.String", "\""),
    ("Token.Punctuation", ")"),
    ("Token.Punctuation", ";"),
    ("Token.Text", " "),
    ("Token.Punctuation", "}"),
    ("Token.Text", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options delphi 11" {
  let lx = @lexers.get_lexer_by_name(
    "delphi",
    options=Map::from_array([("turbopascal", "False"), ("units", "System Math")]),
  )
  let got = lx
    .get_tokens(
      "program P;\nbegin\n  WriteLn('a''b', Sin(1.5), #13, $FF);\n  asm mov eax, 1 end;\nend.\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Name", "program"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "P"),
    ("Token.Operator", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Name", "begin"),
    ("Token.Text.Whitespace", "\n  "),
    ("Token.Name.Builtin", "WriteLn"),
    ("Token.Punctuation", "("),
    ("Token.Literal.String", "'"),
    ("Token.Literal.String", "a"),
    ("Token.Literal.String.Escape", "''"),
    ("Token.Literal.String", "b"),
    ("Token.Literal.String", "'"),
    ("Token.Operator", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Builtin", "Sin"),
    ("Token.Punctuation", "("),
    ("Token.Literal.Number.Float", "1.5"),
    ("Token.Punctuation", ")"),
    ("Token.Operator", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.String.Char", "#13"),
    ("Token.Operator", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Hex", "$FF"),
    ("Token.Punctuation", ")"),
    ("Token.Operator", ";"),
    ("Token.Text.Whitespace", "\n  "),
    ("Token.Name", "asm"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "mov"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "eax"),
    ("Token.Operator", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Integer", "1"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "end"),
    ("Token.Operator", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Name", "end"),
    ("Token.Operator", "."),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options delphi 12" {
  let lx = @lexers.get_lexer_by_name(
    "delphi",
    options=Map::from_array([("portugol", "True")]),
  )
  let got = lx
    .get_tokens(
      "algoritmo \"x\"\nvar a: inteiro\ninicio\n  a <- 1\nfimalgoritmo\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "algoritmo"),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.String", "\""),
    ("Token.Literal.String", "x"),
    ("Token.Literal.String", "\""),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Keyword", "var"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "a"),
    ("Token.Operator", ":"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword.Type", "inteiro"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Keyword", "inicio"),
    ("Token.Text.Whitespace", "\n  "),
    ("Token.Name", "a"),
    ("Token.Text.Whitespace", " "),
    ("Token.Operator", "<-"),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Integer", "1"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Keyword", "fimalgoritmo"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options dasm16 13" {
  let lx = @lexers.get_lexer_by_name("dasm16", options=Map::from_array([]))
  let got = lx
    .get_tokens("SET A, 0x30\n:loop SET PC, loop\nJSR foo\n")
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Name.Function", "SET"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Variable", "A"),
    ("Token.Punctuation", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Literal.Number.Integer", "0x30"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Name.Label", ":loop"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Function", "SET"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Variable", "PC"),
    ("Token.Punctuation", ","),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Label", "loop"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Name.Function", "JSR"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Label", "foo"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}

///|
test "options aspectj 14" {
  let lx = @lexers.get_lexer_by_name("aspectj", options=Map::from_array([]))
  let got = lx
    .get_tokens(
      "aspect A {\n  declare parents: Foo implements Bar;\n  pointcut p(): call(* *(..));\n  int Foo.x;\n  @DeclareParents(\"x\") Foo f;\n}\n",
    )
    .map(t => (t.0.to_string(), t.1))
  let want = [
    ("Token.Keyword", "aspect"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "A"),
    ("Token.Text.Whitespace", " "),
    ("Token.Punctuation", "{"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Text.Whitespace", "  "),
    ("Token.Keyword", "declare"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword", "parents"),
    ("Token.Punctuation", ":"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "Foo"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword.Declaration", "implements"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "Bar"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Text.Whitespace", "  "),
    ("Token.Keyword", "pointcut"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name.Function", "p"),
    ("Token.Punctuation", "("),
    ("Token.Punctuation", ")"),
    ("Token.Punctuation", ":"),
    ("Token.Text.Whitespace", " "),
    ("Token.Keyword", "call"),
    ("Token.Punctuation", "("),
    ("Token.Operator", "*"),
    ("Token.Text.Whitespace", " "),
    ("Token.Operator", "*"),
    ("Token.Punctuation", "("),
    ("Token.Punctuation", "."),
    ("Token.Punctuation", "."),
    ("Token.Punctuation", ")"),
    ("Token.Punctuation", ")"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Text.Whitespace", "  "),
    ("Token.Keyword.Type", "int"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "Foo"),
    ("Token.Punctuation", "."),
    ("Token.Name.Attribute", "x"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Text.Whitespace", "  "),
    ("Token.Name.Decorator", "@DeclareParents"),
    ("Token.Punctuation", "("),
    ("Token.Literal.String", "\""),
    ("Token.Literal.String", "x"),
    ("Token.Literal.String", "\""),
    ("Token.Punctuation", ")"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "Foo"),
    ("Token.Text.Whitespace", " "),
    ("Token.Name", "f"),
    ("Token.Punctuation", ";"),
    ("Token.Text.Whitespace", "\n"),
    ("Token.Punctuation", "}"),
    ("Token.Text.Whitespace", "\n"),
  ]
  assert_eq(got, want)
}
