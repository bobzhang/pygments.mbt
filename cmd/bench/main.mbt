///|
/// Times lexing and formatting of a file (best of `repeat` runs).
/// Usage: bench <alias> <file> [repeat] [formatter]
async fn main {
  let args = @env.args()
  let text = @fs.read_file(args[2]).text()
  let repeat = if args.length() > 3 {
    @string.parse_int(args[3]) catch {
      _ => 1
    }
  } else {
    1
  }
  let fmt_name = if args.length() > 4 { args[4] } else { "terminal256" }
  let lx = @lexers.get_lexer_by_name(args[1])
  let fmt = @formatters.get_formatter_by_name(fmt_name)
  let mut best_lex = 1_000_000L
  let mut best_fmt = 1_000_000L
  let mut n = 0
  for _ in 0..<repeat {
    let t0 = @async.now()
    let toks = lx.get_tokens(text)
    let t1 = @async.now()
    let out = fmt.format(toks)
    let t2 = @async.now()
    n = toks.length() + out.length() * 0
    if t1 - t0 < best_lex {
      best_lex = t1 - t0
    }
    if t2 - t1 < best_fmt {
      best_fmt = t2 - t1
    }
  }
  println("tokens=\{n} lex_ms=\{best_lex} format_ms=\{best_fmt}")
}
