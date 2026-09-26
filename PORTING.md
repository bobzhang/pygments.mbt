# Porting guide: hand-written lexer parts

Most of each lexer is generated from Python by `scripts/export_lexers.py`
into `lexers/gen_*.mbt`. What cannot be generated is written by hand in
`lexers/<module>.mbt` (one file per Python module, e.g. `lexers/c_cpp.mbt`
for `pygments/lexers/c_cpp.py`). `lexers/MANIFEST.md` lists, per lexer, the
MoonBit prefix (`snake_case` of the Python class name) and what is missing.

The exporter discovers hand-written functions **by name**; after adding one,
re-run `python3 scripts/export_lexers.py` so the generated constructor uses
it. Never edit `gen_*.mbt` or `MANIFEST.md` by hand.

| Python | MoonBit (in package `lexers`) |
|---|---|
| `analyse_text(text)` | `fn <prefix>_analyse(text : String) -> Double` |
| bespoke callbacks | `fn <prefix>_callbacks(lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn]` |
| `get_tokens_unprocessed` override, `__init__` options, non-regex lexer, `token_variants` | `fn <prefix>_tokenizer(lx : @lexer.Lexer, text : String, stack : Array[String]) -> Array[@lexer.Token] raise` |

Examples: `lexers/c_cpp.mbt` (tokenizer override + analysers + pydata),
`lexers/bibtex.mbt` (ExtendedRegexLexer callbacks with per-run state).

## Runtime API (`lexer/`)

* `@lexer.run_regex(lx, <prefix>_def.force(), text, stack, callbacks?=...)`
  runs the generated tables (Python's `RegexLexer.get_tokens_unprocessed`).
  For `token_variants` lexers the defs are in `<prefix>_variants`.
* A tokenizer returns `Array[@lexer.Token]` (`{ index, ttype, value }`);
  offsets are UTF-16 offsets. Post-process with ordinary array code.
* Callbacks: `(ctx : @lexer.Ctx, m : @regex.Match, args : Array[@lexer.CallbackArg]) -> Unit raise`.
  The key is the Python qualified name as printed in the manifest
  (e.g. `"YamlLexer.save_indent"`), and `args` holds the values the Python
  factory captured (sorted by closure variable name). Use `ctx.emit(i, t, v)`,
  `ctx.pos`/`ctx.end` (ExtendedRegexLexer), `ctx.push_state(name)`,
  `ctx.pop_state()`, `ctx.state_stack()`, `ctx.set_state_stack(names)`,
  `ctx.apply(action, m)`, `ctx.emit_lexed(lexer, text, offset)`.
  Per-run state (Python `LexerContext` attributes, instance attributes that
  are reset per call) lives in `Ref`s created inside `<prefix>_callbacks`,
  which is called once per tokenization. In a plain `RegexLexer`, after a
  callback the position is `m.end()` regardless of `ctx.pos`.
* Other lexers: call the generated constructor, e.g.
  `python_lexer(options=lx.options)`; `lx.get_tokens_unprocessed(text, stack=[...])`.
  `@lexer.do_insertions(insertions, tokens)` and `@lexer.delegate(...)` port the
  Python helpers of the same name. `@lexer.py_slice(s, a, b)` is Python slicing.
* Options: `lx.options` (`Map[String, String]`), `@lexer.get_bool_opt`,
  `get_int_opt`, `get_list_opt`, `get_choice_opt`.
* Regexes: `@lexer.re(pattern, flags=...)` compiles a trusted pattern at top
  level (`let foo_re : @regex.Regex = @lexer.re("...")`); the engine
  implements Python `re` syntax and semantics (flags `@regex.MULTILINE`,
  `IGNORECASE`, `DOTALL`, `VERBOSE`, `ASCII`). `@lexer.search(re, text)`,
  `@lexer.matches(re, text)`, `re.search(text, pos=..)`, `re.match_at(text, pos)`,
  `m.group(i)`, `m.start(group=i)`, `m.named("x")`, `re.find_all`, `re.replace_all`.
  Python's `re.match` anchors at the position; `re.search` scans.
* `analyse_text` helpers: `@lexer.shebang_matches(text, regex)`,
  `@lexer.doctype_matches`, `@lexer.html_doctype_matches`,
  `@lexer.looks_like_xml`. Return the raw Python value as a `Double`
  (`True` → 1.0, `None`/`False` → 0.0); callers clamp to `[0, 1]`.
  Python `analyse_text` exceptions mean 0.0.
* Python constants (keyword lists, builtin sets, dicts) can be exported instead
  of copied: add a line `// pydata: <name> = <expr>` to your hand-written file,
  where `<expr>` is evaluated with `L.<module>` = `pygments.lexers.<module>`,
  e.g. `// pydata: lua_builtins = L._lua_builtins.MODULES`. It becomes
  `let <name>` in `gen_pydata.mbt` (list → `Array[String]`, set →
  `@set.Set[String]`, dict → `Map`). Names must be globally unique.
* Token types: `@token.name`, `@token.keyword_type`, `@token.string_double`,
  ... (snake_case of the Python path; `@token.from_string("Name.Builtin")`
  for anything else, `t.sub("Child")` for custom subtypes).

## Testing

```
python3 scripts/export_lexers.py
moon build --target native cmd/lexer_oracle
./_build/native/debug/build/cmd/lexer_oracle/lexer_oracle.exe --only <alias> -v
./_build/native/debug/build/cmd/lexer_oracle/lexer_oracle.exe --analyse --only <ClassName>
```

`--only` takes the directory name under `tests/snippets` / `tests/examplefiles`
(a lexer alias) or, with `--analyse`, a Python class name. The corpora in
`.oracle/` are produced by `scripts/lexer_oracle.py` and
`scripts/analyse_oracle.py` from the pinned Python checkout in `.repos/`.
Lexers without test files should still be ported faithfully; add a small
MoonBit test when practical (`lexers/*_test.mbt`, black-box, `@lexers.`).
