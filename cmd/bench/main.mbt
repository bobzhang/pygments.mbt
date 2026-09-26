///|
/// Lexes a file with a lexer alias and prints the token count.
/// Usage: bench <alias> <file> [repeat]
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
  let lx = @lexers.get_lexer_by_name(args[1])
  let mut n = 0
  for _ in 0..<repeat {
    n = lx.get_tokens(text).length()
  }
  println("\{n} tokens")
}
