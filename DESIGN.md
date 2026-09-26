# pygments.mbt — design notes

Port of Pygments (upstream `38f426a6`, cloned at `.repos/pygments`) to MoonBit.

## Facts gathered from the upstream code

* 602 lexers: 489 `RegexLexer` subclasses (17 `ExtendedRegexLexer`, 4 with
  `token_variants`), ~113 others (delegating/template lexers built from
  `DelegatingLexer`, console/session lexers, `TextLexer`, `RawTokenLexer`, ...);
  ~30 RegexLexers override `get_tokens_unprocessed` (keyword post-processing).
* 8,838 unique regex patterns, 1.19 M characters (unistring classes are huge).
  Python `re` features actually used:
  lookahead 930, lookbehind 251, backreference 62, multiline `^` 772 / `$` 777,
  `\b` 1,732, `\s\w\d` 3,116, inline flags 299, conditional `(?(1)..)` 4,
  `\A`/`\Z` 31. Default flags `re.MULTILINE`; also `re.I`, `re.S`, `re.X`, `re.U`.
* Callbacks: `bygroups` 6,403 uses, `using` 61, ~40 bespoke callbacks
  (heredocs, indentation tracking, YAML contexts, ...).
* Conformance data: `tests/examplefiles/*/*.output` (458 dirs, golden token
  streams) and `tests/snippets/**/*.txt` (836 files, input + tokens).

## MoonBit facilities

* `@string.Regex` / `re"..."` / `lexmatch` / `lexscan`: lazy-DFA engine,
  leftmost-first (Perl) priority (verified: `a|ab` on `abc` → `a`).
  No lookaround, no backreferences, no `\s\w\d`, `^`/`$` only at whole-input
  boundaries, `\b` only in runtime patterns, and no anchored "match at pos"
  (`execute(s, last_index=)` searches forward, `^` fails at `last_index>0`).
* `moonbitlang/async` for files, stdin/stdout, processes.

## Proposed architecture

1. **`regex/`** — own backtracking engine with Python `re` syntax and semantics
   (UTF-16 storage, code-point matching, `match_at(text, pos)`, lookaround,
   backrefs, conditionals, inline flags, MULTILINE/DOTALL/IGNORECASE/VERBOSE).
   Memoised compilation. Prefilters (first-char set, literal prefix) for speed.
   Optional fast path: patterns inside the builtin subset are compiled to
   `@string.Regex` over `text[pos:]` with a leading `^` (differentially tested).
2. **`token/`** — hierarchical token types as interned ids with parent links
   (`Token.Name.Builtin`), `is_token_subtype`, `string_to_tokentype`, STANDARD_TYPES
   short names.
3. **`lexer/`** — runtime: `Lexer` trait-object (`get_tokens_unprocessed`),
   `RegexLexer` interpreter over data tables (states → rules → (regex, action,
   transition)), actions = Token | ByGroups | Using | Callback(name),
   transitions = push/pop/pop-n/push-self/combined. `ExtendedRegexLexer`
   context, `DelegatingLexer`, filters, `get_tokens` preprocessing (tabs,
   newline normalisation, stripnl/stripall/ensurenl).
4. **`lexers/`** — *generated* from upstream by `scripts/export_lexers.py`,
   which imports the Python lexers, lets the metaclass resolve
   `include`/`inherit`/`words`/`default`/`combined`, and emits MoonBit data
   (pattern strings + flags + actions). Bespoke callbacks and non-Regex lexers
   are hand-ported MoonBit and referenced by name from the generated tables.
   Metadata (names, aliases, filenames, mimetypes) generated too, for
   `get_lexer_by_name`/`get_lexer_for_filename`/`guess_lexer`
   (`analyse_text` hand-ported, probably using `lexmatch`).
5. **`formatters/`** — html, terminal, terminal256/truecolor, latex, rtf, svg,
   bbcode, irc, groff, pango, raw, testcase, null.
6. **`styles/`** — generated from upstream style classes.
7. **`cmd/pygmentize`** — CLI on `moonbitlang/async` (`@fs`, `@stdio`).
8. **Tests** — generated conformance tests from `tests/snippets` and
   `tests/examplefiles`; the regex engine gets a differential test against
   Python `re` over the patterns actually used.

## Decisions after review (codex, 2026-09-26)

1. **Regex**: one Python-`re` parser + backtracking VM with an explicit stack
   (`match_at(text, pos, endpos?)`), compiled lazily and cached per lexer
   state. The `^`+slice fast path is dropped: slicing changes `^`, `\A`, `\b`
   and lookbehind context. The builtin DFA may later serve proven-equivalent
   patterns whose action only needs the whole-match span.
   Unsupported constructs raise at compile time (never silently mis-match).
   Unicode tables for `\w`, `\d`, `\s` and IGNORECASE folding are generated
   from the pinned CPython (3.14) so semantics match the oracle.
2. **Indexing**: text is kept as a MoonBit UTF-16 `String`; matching is on
   code points (`.`/classes consume surrogate pairs, lookbehind widths count
   code points, error recovery consumes one code point). Offsets reported by
   `get_tokens_unprocessed` are UTF-16 offsets — a documented deviation from
   Python's code-point offsets; conformance compares `(token, text)` streams,
   and a helper converts offsets when needed.
3. **Budgets**: every match call runs under a step budget shared by the whole
   lexing request (including `using` delegation); exhaustion raises a
   distinct error instead of being treated as "no match".
4. **Actions** are typed: `Token(t)`, `ByGroups(Array[Action?])`,
   `Using(target, state, options)`, `UsingThis(...)`, `Callback(id)`;
   transitions: `Push(states)`, `Pop(n)`, `PushSelf`, mixed sequences.
   Bespoke callbacks, `ExtendedRegexLexer` contexts, `token_variants`,
   `DelegatingLexer` and `get_tokens_unprocessed` overrides are hand-ported.
5. **Generation**: `scripts/export_lexers.py` instruments `bygroups`/`using`
   and friends during import, emits deterministic MoonBit tables plus a
   manifest, and fails on unrecognised callables.
6. **Tokens**: interned ids with parent links, open hierarchy, canonical
   names for serialisation.
7. **Conformance**: pinned Python oracle; regex differential tests (spans of
   all groups at varied positions); snippet/examplefile token streams;
   formatter snapshots.

## Styles, filters, formatters

* `styles/`: `Style::new` replays `StyleMeta` on the raw `styles` entries;
  `styles/gen_*.mbt` (one per upstream module) come from
  `scripts/export_styles.py`. `get_style_by_name`, `get_all_styles`.
* `filters/`: the eight builtin filters as `@lexer.Filter` values
  (`get_filter_by_name`); `SymbolFilter` tables from
  `scripts/export_filters.py`. `raiseonerror` raises `ErrorToken` (no
  `excclass`).
* `pystr/`: Python string semantics the formatters need (`repr`, `ascii`,
  `splitlines`, `expandtabs`, full-Unicode `lower`/`upper`/`capitalize`),
  tables from `scripts/gen_pystr_tables.py`.
* `formatters/`: every formatter except the PIL image formatters (`img`,
  `gif`, `jpg`, `bmp`), which need the Python Imaging Library to rasterise
  text and are not ported. Options are strings, as on the command line;
  Python truthiness of string options is kept (`linenos=False` given as a
  string enables line numbers in the HTML formatter, as in Python). No file
  IO: `format` returns a `String`, and the HTML `cssfile` is reported by
  `Formatter::aux_files` for the caller to write. Not supported: HTML
  `tagsfile` (needs `ctags`), raw `compress=gz|bz2`, non-string options
  (`colorscheme` is a constructor argument of the terminal/IRC formatters).
* Conformance: `scripts/formatter_oracle.py` stores token streams and Python
  outputs in `.oracle/formatters.jsonl`; `cmd/formatter_oracle` replays them
  byte for byte (formatters × options × styles, `get_style_defs`, style
  dictionaries of every builtin style, filters, `LatexEmbeddedLexer`).
