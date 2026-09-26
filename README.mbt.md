# pygments.mbt

[![CI](https://github.com/bobzhang/pygments.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/bobzhang/pygments.mbt/actions/workflows/ci.yml)

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
* All non-image formatters (HTML, terminal/256/true-color, LaTeX, RTF, SVG,
  BBCode, IRC, groff, Pango, raw, testcase), all 50 styles and all 8 filters,
  byte-identical to Python on 5,480 differential cases.
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

Render with any formatter (`html`, `terminal256`, `latex`, `rtf`, `svg`, …):

```mbt check
///|
test "highlight to HTML" {
  let html = @pygments.highlight(
    "print('hi')\n",
    @pygments.get_lexer_by_name("python"),
    @pygments.get_formatter_by_name("html", options={ "noclasses": "True" }),
  )
  inspect(html.has_prefix("<div class=\"highlight\""), content="true")
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

## Command line

`cmd/pygmentize` mirrors Python's `pygmentize` (`-l -g -f -O -P -F -o -s -S -a
-L -N -C -H -V`, `--json`); a differential script compares both
implementations (`scripts/cli_compare.py`):

```bash
# run straight from mooncakes.io, no checkout needed
moonx bobzhang/pygments/cmd/pygmentize -f terminal256 -O style=monokai main.py
# or build it (native or wasm)
moon build --target native --release cmd/pygmentize
./_build/native/release/build/cmd/pygmentize/pygmentize.exe -f terminal256 -O style=monokai main.py
```

Not supported: `-x` (loading lexers/formatters from Python files) and the PIL
image formatters (`img`, `gif`, `jpg`, `bmp`), which are listed but raise, as
in Python without PIL.

## Layout

| Package | Contents |
|---|---|
| `regex/` | Python-`re` compatible backtracking regex engine |
| `token/` | token type hierarchy (`Token.Name.Builtin`, …) |
| `lexer/` | lexer runtime: `RegexLexer`/`ExtendedRegexLexer` interpreter, `DelegatingLexer`, `do_insertions`, options |
| `lexers/` | all lexers: tables generated from upstream (`gen_*.mbt`) plus hand-written parts, registry |
| `styles/`, `formatters/`, `filters/` | styles, output formatters and token filters |
| `cmd/pygmentize` | the command line tool |
| `pystr/` | Python string semantics used by the formatters (`repr`, case mapping, …) |
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

The upstream checkout is pinned in `scripts/PYGMENTS_COMMIT`; CI runs the same
scripts on every push.

```bash
moon test                       # unit tests (also --target js / wasm-gc)
scripts/conformance.sh          # differential tests against Python 3.14 + Pygments
scripts/regen.sh                # regenerate all generated MoonBit files
```

## License

BSD-2-Clause, like Pygments. The lexer tables and styles are derived from
Pygments (Copyright 2006-present by the Pygments team, see its AUTHORS).
