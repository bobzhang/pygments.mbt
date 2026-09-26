// Hand-written parts of pygments/lexers/dotnet.py.

///|
/// `__init__` of the `token_variants` lexers: the `unicodelevel` option
/// (`none`, `basic` or `full`, default `basic`) picks the token table.
fn unicodelevel_def(
  lx : @lexer.Lexer,
  variants : Array[(String, @lazy.Lazy[@lexer.RegexDef])],
) -> @lexer.RegexDef raise {
  let levels = variants.map(v => v.0)
  let level = @lexer.get_choice_opt(lx.options, "unicodelevel", levels, "basic")
  for v in variants {
    if v.0 == level {
      return v.1.force()
    }
  }
  abort("unreachable: unknown unicodelevel \{level}")
}

///|
fn c_sharp_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    unicodelevel_def(lx, c_sharp_lexer_variants),
    text,
    stack,
  )
}

///|
fn nemerle_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  stack : Array[String],
) -> Array[@lexer.Token] raise {
  @lexer.run_regex(
    lx,
    unicodelevel_def(lx, nemerle_lexer_variants),
    text,
    stack,
  )
}

///|
fn nemerle_lexer_analyse(text : String) -> Double {
  if text.contains("@if") {
    0.1
  } else {
    0.0
  }
}

///|
let vb_net_re : @regex.Regex = @lexer.re(
  "^\\s*(#If|Module|Namespace)",
  flags=@regex.MULTILINE,
)

///|
fn vb_net_lexer_analyse(text : String) -> Double {
  if @lexer.search(vb_net_re, text) {
    0.5
  } else {
    0.0
  }
}

///|
let c_sharp_aspx_page_re : @regex.Regex = @lexer.re(
  "Page\\s*Language=\"C#\"",
  flags=@regex.IGNORECASE,
)

///|
let c_sharp_aspx_script_re : @regex.Regex = @lexer.re(
  "script[^>]+language=[\"']C#",
  flags=@regex.IGNORECASE,
)

///|
fn c_sharp_aspx_lexer_analyse(text : String) -> Double {
  if @lexer.search(c_sharp_aspx_page_re, text) {
    0.2
  } else if @lexer.search(c_sharp_aspx_script_re, text) {
    0.15
  } else {
    0.0
  }
}

///|
let vb_net_aspx_page_re : @regex.Regex = @lexer.re(
  "Page\\s*Language=\"Vb\"",
  flags=@regex.IGNORECASE,
)

///|
let vb_net_aspx_script_re : @regex.Regex = @lexer.re(
  "script[^>]+language=[\"']vb",
  flags=@regex.IGNORECASE,
)

///|
fn vb_net_aspx_lexer_analyse(text : String) -> Double {
  if @lexer.search(vb_net_aspx_page_re, text) {
    0.2
  } else if @lexer.search(vb_net_aspx_script_re, text) {
    0.15
  } else {
    0.0
  }
}

///|
/// `FSharpLexer.analyse_text`: `|>` and `<|` are weak indicators.
fn f_sharp_lexer_analyse(text : String) -> Double {
  let mut result = 0.0
  if text.contains("|>") {
    result += 0.05
  }
  if text.contains("<|") {
    result += 0.05
  }
  result
}
