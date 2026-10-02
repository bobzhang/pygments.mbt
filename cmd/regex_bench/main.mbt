///|
/// Regex engine micro-benchmarks over synthetic inputs (no file system, so it
/// runs on every backend). Each case reports the best of `repeat` runs and a
/// checksum of all match spans (it must not change between engine versions).
///
/// Usage: regex_bench [repeat] [case-filter]
///        regex_bench --dump   (inputs and results as JSON lines, checked
///                             against Python by scripts/regex_bench_oracle.py)
fn main {
  let args = @env.args()
  if args.length() > 1 && args[1] == "--dump" {
    dump()
    return
  }
  let repeat = if args.length() > 1 {
    @string.parse_int(args[1]) catch {
      _ => 5
    }
  } else {
    5
  }
  let filter = if args.length() > 2 { args[2] } else { "" }
  let cases : Array[(String, () -> Int)] = [
    ("repr find_all", bench_repr(repr_lines(20000))),
    ("json find_all", bench_json(json_docs(800))),
    ("lexer match_at", bench_tokenize(python_text(4000))),
    ("lexer match_end", bench_tokenize_end(python_text(4000))),
    ("rare search", bench_rare(log_text(300000))),
  ]
  for case in cases {
    let (name, run) = case
    if filter != "" && !name.contains(filter) {
      continue
    }
    let mut best = 1_000_000_000UL
    let mut sum = 0
    for _ in 0..<repeat {
      let t0 = @env.now()
      sum = run()
      let t1 = @env.now()
      if t1 - t0 < best {
        best = t1 - t0
      }
    }
    println("\{name}: \{best} ms (checksum \{sum})")
  }
}

///|
/// Deterministic pseudo-random numbers.
priv struct Lcg {
  mut state : UInt
}

///|
fn Lcg::next(self : Lcg, n : Int) -> Int {
  self.state = self.state * 1664525U + 1013904223U
  ((self.state >> 8).reinterpret_as_int() & 0x7FFFFF) % n
}

///|
/// A backslash followed by a double quote.
let esc_dq : String = "\\\""

///|
/// A backslash followed by a single quote.
let esc_sq : String = "\\'"

///|
fn hex(n : Int, width : Int) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for i = width - 1; i >= 0; i = i - 1 {
    sb.write_char(digits.get_char((n >> (i * 4)) & 15).unwrap())
  }
  sb.to_string()
}

///|
/// Lines like the ones Rich's `ReprHighlighter` sees when pretty-printing.
fn repr_lines(n : Int) -> Array[String] {
  let rng : Lcg = { state: 42, }
  let out = []
  for i in 0..<n {
    let k = rng.next(100000)
    let line = match i % 10 {
      0 =>
        "{'name': 'user_\{k}', 'id': \{k}, 'score': \{k % 97}.5, 'tags': ['alpha', 'beta', \"say \\\"hi\\\"\"], 'active': True, 'parent': None}"
      1 => "<Response [200]> <Foo bar=\{k} baz='qux' enabled=False>"
      2 =>
        "Point(x=\{k}, y=-\{k % 13}.25e-3, z=3+4j, w=1e10) at 0x7f\{hex(k, 8)}"
      3 =>
        "[IPv4Address('192.168.\{k % 256}.1'), IPv6Address('2001:db8::\{hex(k, 4)}'), 'https://example.com/api/v1/items/\{k}?q=x&page=2']"
      4 =>
        "PosixPath('/usr/local/lib/python3.14/site-packages/pkg_\{k}/module.py')"
      5 =>
        "UUID('\{hex(k, 8)}-1234-5678-9abc-\{hex(k, 8)}\{hex(k, 4)}'), datetime.datetime(2024, 1, \{k % 28 + 1}, 12, 30, 45)"
      6 =>
        "Processing item \{k} of 100000: status=ok elapsed=0.\{k % 1000}s worker=thread-\{k % 8} queue_depth=\{k % 50}"
      7 =>
        "b'\\x00\\x01 bytes' ... False ... {'nested': {'deep': [1, 2, [3, 4, [5, ...]]]}}"
      8 =>
        "    'description': 'A fairly long string value that goes on for a while without any spécial tökens in it at all 😀',"
      _ =>
        "Mac('00:1a:2b:3c:4d:\{hex(k % 256, 2)}') eui64=00-1a-2b-ff-fe-3c-4d-5e, ratio=\{k % 7}.\{k % 100}"
    }
    out.push(line)
  }
  out
}

///|
let repr_patterns : Array[String] = [
  "(?P<tag_start><)(?P<tag_name>[-\\w.:|]*)(?P<tag_contents>[\\w\\W]*)(?P<tag_end>>)",
  "(?P<attrib_name>[\\w_]{1,50})=(?P<attrib_value>\"?[\\w_]+\"?)?",
  "(?P<brace>[][{}()])",
  [
    "(?P<ipv4>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})", "(?P<ipv6>([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})",
    "(?P<eui64>(?:[0-9A-Fa-f]{1,2}-){7}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{1,2}:){7}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{4}\\.){3}[0-9A-Fa-f]{4})",
    "(?P<eui48>(?:[0-9A-Fa-f]{1,2}-){5}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{1,2}:){5}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{4}\\.){2}[0-9A-Fa-f]{4})",
    "(?P<uuid>[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})",
    "(?P<call>[\\w.]*?)\\(", "\\b(?P<bool_true>True)\\b|\\b(?P<bool_false>False)\\b|\\b(?P<none>None)\\b",
    "(?P<ellipsis>\\.\\.\\.)", "(?P<number_complex>(?<!\\w)(?:\\-?[0-9]+\\.?[0-9]*(?:e[-+]?\\d+?)?)(?:[-+](?:[0-9]+\\.?[0-9]*(?:e[-+]?\\d+)?))?j)",
    "(?P<number>(?<!\\w)\\-?[0-9]+\\.?[0-9]*(e[-+]?\\d+?)?\\b|0x[0-9a-fA-F]*)", "(?P<path>\\B(/[-\\w._+]+)*\\/)(?P<filename>[-\\w._+]*)?",
    "(?<![\\\\\\w])(?P<str>b?'''.*?(?<!\\\\)'''|b?'.*?(?<!\\\\)'|b?\\\"\\\"\\\".*?(?<!\\\\)\\\"\\\"\\\"|b?\\\".*?(?<!\\\\)\\\")",
    "(?P<url>(file|https|http|ws|wss)://[-0-9a-zA-Z$_+!`(),.?/;:&=%#~@]*)",
  ].join("|"),
]

///|
/// Sum of all group spans of all matches: a cheap fingerprint.
fn spans_checksum(ms : Array[@regex.Match]) -> Int {
  let mut sum = 0
  for m in ms {
    for g in 0..<=m.group_count() {
      sum = sum * 31 + m.start(group=g) * 7 + m.end(group=g)
    }
  }
  sum
}

///|
fn compile_all(patterns : Array[String]) -> Array[@regex.Regex] {
  patterns.map(p => {
    @regex.compile(p) catch {
      e => abort("bad pattern \{p}: \{Repr(e)}")
    }
  })
}

///|
fn bench_repr(lines : Array[String]) -> () -> Int {
  let res = compile_all(repr_patterns)
  fn() {
    let mut sum = 0
    for line in lines {
      for re in res {
        let ms = re.find_all(line) catch { _ => abort("budget") }
        sum = sum * 17 + spans_checksum(ms)
      }
    }
    sum
  }
}

///|
/// Pretty-printed JSON documents (Rich's `JSONHighlighter` input).
fn json_docs(n : Int) -> Array[String] {
  let rng : Lcg = { state: 7, }
  let out = []
  for _ in 0..<n {
    let sb = StringBuilder()
    sb.write_string("[\n")
    for j in 0..<20 {
      let k = rng.next(100000)
      sb.write_string(
        (
          $|  {
          $|    "id": \{k},
          $|    "name": "item \{k} with \{esc_dq}quotes\{esc_dq}",
          $|    "price": \{k % 1000}.5,
          $|    "tags": ["x", "y", "z\{j}"],
          $|    "in_stock": true,
          $|    "discount": null,
          $|    "dims": {"w": 1.0e-3, "h": -\{k % 9}}
          $|  },
          $|
        ),
      )
    }
    sb.write_string("]\n")
    out.push(sb.to_string())
  }
  out
}

///|
let json_str_pattern : String = "(?<![\\\\\\w])(?P<str>b?\\\".*?(?<!\\\\)\\\")"

///|
let json_patterns : Array[String] = [
  [
    "(?P<brace>[\\{\\[\\(\\)\\]\\}])", "\\b(?P<bool_true>true)\\b|\\b(?P<bool_false>false)\\b|\\b(?P<null>null)\\b",
    "(?P<number>(?<!\\w)\\-?[0-9]+\\.?[0-9]*(e[\\-\\+]?\\d+?)?\\b|0x[0-9a-fA-F]*)",
    json_str_pattern,
  ].join("|"),
  json_str_pattern,
]

///|
fn bench_json(docs : Array[String]) -> () -> Int {
  let res = compile_all(json_patterns)
  fn() {
    let mut sum = 0
    for doc in docs {
      for re in res {
        let ms = re.find_all(doc) catch { _ => abort("budget") }
        sum = sum * 17 + spans_checksum(ms)
      }
    }
    sum
  }
}

///|
/// Python-like source text.
fn python_text(n : Int) -> String {
  let rng : Lcg = { state: 99, }
  let sb = StringBuilder()
  for i in 0..<n {
    let k = rng.next(1000)
    sb.write_string(
      (
        $|def handler_\{i}(request, *args, timeout=\{k}.5, **kwargs):
        $|    """Handle request number \{i}."""
        $|    # check the cache first
        $|    if request.path in CACHE and not kwargs.get('fresh', False):
        $|        return CACHE[request.path]  # hit
        $|    result = compute(request.body, 0x\{hex(k, 4)}, 1e-\{k % 9}) + len(args)
        $|    for item in result.items:
        $|        print(f"item {item!r}", 'single \{esc_sq}quoted\{esc_sq}', sep=", ")
        $|    return result
        $|
        $|
      ),
    )
  }
  sb.to_string()
}

///|
let token_patterns : Array[(String, Int)] = [
  ("\\n", 0),
  ("[^\\S\\n]+", 0),
  ("#.*$", @regex.MULTILINE),
  ("(\"\"\"|''')(?:(?!\\1)(?:\\\\.|[^\\\\]))*\\1", 0),
  (
    "(?:def|class|return|if|elif|else|for|while|in|not|and|or|import|from|as|with|try|except|finally|lambda|yield|pass|break|continue)\\b",
    0,
  ),
  ("(?:True|False|None)\\b", 0),
  ("[fFrRbB]{0,2}\"(?:\\\\.|[^\"\\\\\\n])*\"", 0),
  ("[fFrRbB]{0,2}'(?:\\\\.|[^'\\\\\\n])*'", 0),
  (
    "(\\d(?:_?\\d)*\\.(?:\\d(?:_?\\d)*)?|\\.\\d(?:_?\\d)*)([eE][+-]?\\d(?:_?\\d)*)?j?",
    0,
  ),
  ("\\d(?:_?\\d)*[eE][+-]?\\d(?:_?\\d)*j?", 0),
  ("0[xX](?:_?[a-fA-F0-9])+", 0),
  ("\\d(?:_?\\d)*", 0),
  ("(?P<name>[^\\W\\d]\\w*)(?=\\s*\\()", 0),
  ("[^\\W\\d]\\w*", 0),
  ("\\*\\*|//|<<|>>|[-+*/%&|^~<>=!]=?", 0),
  ("[()\\[\\]{}:;,.@]", 0),
]

///|
fn compile_tokens() -> Array[@regex.Regex] {
  token_patterns.map(p => {
    @regex.compile(p.0, flags=p.1) catch {
      e => abort("bad pattern \{p.0}: \{Repr(e)}")
    }
  })
}

///|
/// A `RegexLexer`-style loop: at each position, the first rule that matches
/// (via `match_at`, which allocates a `Match`) wins.
fn bench_tokenize(text : String) -> () -> Int {
  let res = compile_tokens()
  fn() {
    let budget = @regex.Budget::new(1_000_000_000)
    let mut sum = 0
    let mut pos = 0
    let n = text.length()
    while pos < n {
      let mut next = pos + 1
      for i, re in res {
        let r = re.match_at(text, pos, budget~) catch { _ => abort("budget") }
        if r is Some(m) {
          if m.end() > pos {
            next = m.end()
          }
          sum = sum * 31 + i + m.end()
          break
        }
      }
      pos = next
    }
    sum
  }
}

///|
/// Like `bench_tokenize`, with the dispatch the pygments lexer uses:
/// `may_start_with` first, then `match_end` (no `Match` allocation).
fn bench_tokenize_end(text : String) -> () -> Int {
  let res = compile_tokens()
  fn() {
    let budget = @regex.Budget::new(1_000_000_000)
    let mut sum = 0
    let mut pos = 0
    let n = text.length()
    while pos < n {
      let c = text.unsafe_get(pos).to_int()
      let mut next = pos + 1
      for i, re in res {
        if !re.may_start_with(c) {
          continue
        }
        let e = re.match_end(text, pos, budget~) catch { _ => abort("budget") }
        if e >= 0 {
          if e > pos {
            next = e
          }
          sum = sum * 31 + i + e
          break
        }
      }
      pos = next
    }
    sum
  }
}

///|
/// A long log where the searched-for lines are rare.
fn log_text(n : Int) -> String {
  let rng : Lcg = { state: 3, }
  let sb = StringBuilder()
  for i in 0..<n {
    let k = rng.next(1000)
    if k == 0 {
      sb.write_string(
        "2024-05-01 12:00:\{i % 60} ERROR: disk quota exceeded for user_\{k}\n",
      )
    } else if k == 1 {
      sb.write_string("see https://example.com/issue/\{i} for details\n")
    } else {
      sb.write_string(
        "2024-05-01 12:00:\{i % 60} INFO: request \{i} served in \{k} ms by worker-\{k % 8}\n",
      )
    }
  }
  sb.to_string()
}

///|
let rare_patterns : Array[String] = [
  "\\b(?:ERROR|FATAL)\\b: (?P<msg>.*)", "https?://[^\\s]+", "(?i)quota\\s+exceeded",
]

///|
fn bench_rare(text : String) -> () -> Int {
  let res = compile_all(rare_patterns)
  fn() {
    let mut sum = 0
    for re in res {
      let ms = re.find_all(text) catch { _ => abort("budget") }
      sum = sum * 17 + spans_checksum(ms)
    }
    sum
  }
}

///|
fn match_spans(ms : Array[@regex.Match]) -> Array[Int] {
  let out = []
  for m in ms {
    for g in 0..<=m.group_count() {
      out.push(m.start(group=g))
      out.push(m.end(group=g))
    }
  }
  out
}

///|
fn dump_find_all(
  name : String,
  patterns : Array[String],
  texts : Array[String],
) -> Unit {
  let res = compile_all(patterns)
  let spans : Array[Array[Int]] = []
  for t in texts {
    for re in res {
      spans.push(match_spans(re.find_all(t) catch { _ => abort("budget") }))
    }
  }
  let obj : Json = {
    "kind": "find_all",
    "name": name,
    "patterns": patterns.to_json(),
    "texts": texts.to_json(),
    "spans": spans.to_json(),
  }
  println(obj.stringify())
}

///|
fn dump_tokenize(text : String) -> Unit {
  let res = compile_tokens()
  let tokens : Array[Array[Int]] = []
  let mut pos = 0
  let n = text.length()
  while pos < n {
    let mut next = pos + 1
    for i, re in res {
      let r = re.match_at(text, pos) catch { _ => abort("budget") }
      if r is Some(m) {
        if m.end() > pos {
          next = m.end()
        }
        tokens.push([pos, i, ..match_spans([m])])
        break
      }
    }
    pos = next
  }
  let obj : Json = {
    "kind": "tokenize",
    "name": "lexer match_at",
    "patterns": token_patterns
    .map(p => [p.0.to_json(), p.1.to_json()])
    .to_json(),
    "texts": [text].to_json(),
    "spans": tokens.to_json(),
  }
  println(obj.stringify())
}

///|
fn dump() -> Unit {
  dump_find_all("repr find_all", repr_patterns, repr_lines(2000))
  dump_find_all("json find_all", json_patterns, json_docs(40))
  dump_find_all("rare search", rare_patterns, [log_text(20000)])
  dump_tokenize(python_text(300))
}
