///|
fn mbt_tokens(src : String) -> String raise {
  let lx = @lexers.get_lexer_by_name("moonbit")
  let toks = lx.get_tokens(src)
  assert_eq(toks.map(t => t.1).join(""), src)
  toks
  .filter(t => t.1.trim().length() > 0)
  .map(t => {
    "\{t.0.to_string().unsafe_substring(start=6, end=t.0.to_string().length())} \{t.1}"
  })
  .join("\n")
}

///|
test "moonbit lexer" {
  let src =
    #|///|
    #|/// Doc comment
    #|#deprecated
    #|pub fn[T : Show] Point::show(self : Point, n~ : Int) -> String raise {
    #|  let s = "x=\{self.x + 1}\n"
    #|  let re = re"[a-z]+"
    #|  let m = $|line \{n}
    #|  guard n is 0x1F..=0b11 else { fail("bad") }
    #|  @json.parse(s) |> ignore
    #|  'c'
    #|}
    #|
  inspect(
    mbt_tokens(src),
    content=(
      #|Comment.Special ///|
      #|Literal.String.Doc /// Doc comment
      #|Name.Decorator #deprecated
      #|Keyword pub
      #|Keyword.Declaration fn
      #|Punctuation [
      #|Name.Class T
      #|Punctuation :
      #|Name.Class Show
      #|Punctuation ]
      #|Name.Class Point
      #|Punctuation ::
      #|Name.Function show
      #|Punctuation (
      #|Keyword self
      #|Punctuation :
      #|Name.Class Point
      #|Punctuation ,
      #|Name n
      #|Operator ~
      #|Punctuation :
      #|Keyword.Type Int
      #|Punctuation )
      #|Operator ->
      #|Keyword.Type String
      #|Keyword raise
      #|Punctuation {
      #|Keyword let
      #|Name s
      #|Operator =
      #|Literal.String.Double "
      #|Literal.String.Double x=
      #|Literal.String.Interpol \{
      #|Keyword self
      #|Punctuation .
      #|Name x
      #|Operator +
      #|Literal.Number.Integer 1
      #|Literal.String.Interpol }
      #|Literal.String.Escape \n
      #|Literal.String.Double "
      #|Keyword let
      #|Name re
      #|Operator =
      #|Literal.String.Regex re"
      #|Literal.String.Regex [a-z]+
      #|Literal.String.Regex "
      #|Keyword let
      #|Name m
      #|Operator =
      #|Literal.String $|
      #|Literal.String line 
      #|Literal.String.Interpol \{
      #|Name n
      #|Literal.String.Interpol }
      #|Keyword guard
      #|Name n
      #|Keyword is
      #|Literal.Number.Hex 0x1F
      #|Operator ..=
      #|Literal.Number.Bin 0b11
      #|Keyword else
      #|Punctuation {
      #|Name.Builtin fail
      #|Punctuation (
      #|Literal.String.Double "
      #|Literal.String.Double bad
      #|Literal.String.Double "
      #|Punctuation )
      #|Punctuation }
      #|Name.Namespace @json
      #|Punctuation .
      #|Name parse
      #|Punctuation (
      #|Name s
      #|Punctuation )
      #|Operator |>
      #|Name.Builtin ignore
      #|Literal.String.Char 'c'
      #|Punctuation }
    ),
  )
  inspect(@lexers.get_lexer_for_filename("main.mbt").name(), content="MoonBit")
}

///|
test "moonbit content detection" {
  let src =
    #|///|
    #|fn main {
    #|  println("hi")
    #|}
    #|
  inspect(@lexers.guess_lexer(src).name(), content="MoonBit")
  let hints =
    #|fn main {
    #|  println(@json.stringify(1))
    #|}
    #|
  inspect(@lexers.guess_lexer(hints).name(), content="MoonBit")
  // Rust is not mistaken for MoonBit
  let rust =
    #|fn main() {
    #|    println!("hi");
    #|}
    #|
  inspect((@lexers.moon_bit_lexer_info.analyse_text)(rust), content="0")
  // a single weak hint is not enough
  let python =
    #|@app.route("/")
    #|def index():
    #|    return render(x)
    #|
  inspect((@lexers.moon_bit_lexer_info.analyse_text)(python), content="0")
  let rails =
    #|test "creates a user" do
    #|  assert User.create
    #|end
    #|
  inspect((@lexers.moon_bit_lexer_info.analyse_text)(rails), content="0")
}
