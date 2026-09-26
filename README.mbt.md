# pygments.mbt

A port of [Pygments](https://pygments.org) 2.21 — the generic syntax
highlighter — to MoonBit.

* **All 615 lexers** of upstream Pygments, token-for-token compatible: the
  1,508 lexer tests of the upstream test suite plus 6,600 cross-fed inputs
  produce identical token streams, and every `analyse_text`/`guess_lexer`
  result matches.
* A **Python-`re` compatible regex engine** (`regex/`): lookaround,
  backreferences, conditionals, inline/scoped flags, verbose mode, Unicode
  `\w\d\s` and case folding generated from CPython 3.14, a step budget
  against catastrophic backtracking. Differentially tested against CPython on
  all 8,838 patterns used by the lexers.
* Formatters (HTML, terminal, LaTeX, RTF, SVG, …), styles and filters.
* A `pygmentize` command line tool built on `moonbitlang/async`.

## Usage

```mbt check
///|
test "lex some Python" {
  let lexer = @lexers.get_lexer_by_name("python")
  let tokens = @pygments.lex("print('hi')\n", lexer)
  inspect(
    tokens.map(t => "\{t.0} \{t.1.escape()}").join("\n"),
    content=(
      #|Token.Name.Builtin "print"
      #|Token.Punctuation "("
      #|Token.Literal.String.Single "'"
      #|Token.Literal.String.Single "hi"
      #|Token.Literal.String.Single "'"
      #|Token.Punctuation ")"
      #|Token.Text.Whitespace "\n"
    ),
  )
}
```

Lexers can be looked up by alias, file name, MIME type or content:

```mbt check
///|
test "lexer lookup" {
  inspect(@lexers.get_lexer_for_filename("main.rs").name(), content="Rust")
  inspect(
    @lexers.guess_lexer("#!/usr/bin/env python3\nimport os\n").name(),
    content="Python",
  )
}
```

## Layout

| Package | Contents |
|---|---|
| `regex/` | Python-`re` compatible backtracking regex engine |
| `token/` | token type hierarchy (`Token.Name.Builtin`, …) |
| `lexer/` | lexer runtime: `RegexLexer`/`ExtendedRegexLexer` interpreter, `DelegatingLexer`, `do_insertions`, options |
| `lexers/` | all lexers: tables generated from upstream (`gen_*.mbt`) plus hand-written parts, registry |
| `styles/`, `formatters/`, `filters/` | styles, output formatters and token filters |
| `cmd/pygmentize` | the command line tool |
| `cmd/*_oracle` | differential test drivers against Python |

## How the port works

`scripts/export_lexers.py` imports the pinned upstream checkout
(`.repos/pygments`), lets Pygments' own metaclass resolve `include`,
`inherit`, `words()`, `default` and `combined`, and emits the processed
state tables as MoonBit data. Parts that are Python code — callbacks,
`get_tokens_unprocessed` overrides, non-regex lexers, `analyse_text` — are
hand-ported in `lexers/<module>.mbt` and discovered by name; see
[PORTING.md](PORTING.md) and [DESIGN.md](DESIGN.md).

Offsets reported by `get_tokens_unprocessed` are UTF-16 offsets (MoonBit
strings), while matching itself is code-point based like Python.

## Testing against Python

```bash
git clone --depth 1 https://github.com/pygments/pygments .repos/pygments
python3 scripts/regex_oracle.py .oracle/regex.jsonl
python3 scripts/lexer_oracle.py .oracle/lexers.jsonl
python3 scripts/analyse_oracle.py .oracle/lexers.jsonl .oracle/analyse.jsonl
moon build --target native --release
./_build/native/release/build/cmd/regex_oracle/regex_oracle.exe
./_build/native/release/build/cmd/lexer_oracle/lexer_oracle.exe --quiet
./_build/native/release/build/cmd/lexer_oracle/lexer_oracle.exe --analyse --quiet
```

## License

BSD-2-Clause, like Pygments. The lexer tables and styles are derived from
Pygments (Copyright 2006-present by the Pygments team, see its AUTHORS).
