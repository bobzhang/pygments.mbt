///|
/// Metadata of Python's `LatexEmbeddedLexer` (not registered as a lexer).
let latex_embedded_info : @lexer.LexerInfo = {
  class_name: "LatexEmbeddedLexer",
  name: "",
  aliases: [],
  filenames: [],
  alias_filenames: [],
  mimetypes: [],
  priority: 0.0,
  url: "",
  version_added: "",
  analyse_text: _ => 0.0,
  doc: "",
}

///|
/// Python's `LatexEmbeddedLexer`: lexes with `lang`, but text between the
/// delimiters `left` and `right` outside strings and comments becomes an
/// `Escape` token (raw LaTeX for the `LatexFormatter`). The options of
/// `lang` are inherited; `options` override them.
pub fn latex_embedded_lexer(
  left : String,
  right : String,
  lang : @lexer.Lexer,
  options? : @lexer.Options = Map([]),
) -> @lexer.Lexer raise {
  let merged = lang.options.copy()
  for k, v in options {
    merged[k] = v
  }
  @lexer.Lexer::new(
    latex_embedded_info,
    merged,
    o => latex_embedded_lexer(left, right, lang, options=o),
    (_, text, _) => {
      // find and remove all the escape tokens (replace with an empty string)
      let buffered = StringBuilder()
      let mut buffered_len = 0
      let insertions : Array[(Int, Array[@lexer.Token])] = []
      let insertion_buf : Array[@lexer.Token] = []
      for item in find_safe_escape_tokens(left, right, lang, text) {
        let (i, t, v) = item
        match t {
          None => {
            if insertion_buf.length() > 0 {
              insertions.push((buffered_len, insertion_buf.copy()))
              insertion_buf.clear()
            }
            buffered.write_string(v)
            buffered_len += v.length()
          }
          Some(t) => insertion_buf.push({ index: i, ttype: t, value: v, })
        }
      }
      if insertion_buf.length() > 0 {
        insertions.push((buffered_len, insertion_buf.copy()))
      }
      @lexer.do_insertions(
        insertions,
        lang.get_tokens_unprocessed(buffered.to_string()),
      )
    },
  )
}

///|
/// Python's `_find_safe_escape_tokens`: escape tokens outside strings and
/// comments; `None` marks text to be lexed again.
fn find_safe_escape_tokens(
  left : String,
  right : String,
  lang : @lexer.Lexer,
  text : String,
) -> Array[(Int, @token.TokenType?, String)] raise {
  let out = []
  let pred = (t : @token.TokenType) => {
    t.is_subtype_of(@token.comment) || t.is_subtype_of(@token.string)
  }
  for item in filter_to(lang.get_tokens_unprocessed(text), pred) {
    let (i, t, v) = item
    match t {
      None =>
        for e in find_escape_tokens(left, right, v) {
          out.push((i + e.0, e.1, e.2))
        }
      Some(_) => out.push((i, None, v))
    }
  }
  out
}

///|
/// Python's `_filter_to`: keeps the tokens matching `pred` and merges the
/// others (their type becomes `None`).
fn filter_to(
  tokens : Array[@lexer.Token],
  pred : (@token.TokenType) -> Bool,
) -> Array[(Int, @token.TokenType?, String)] {
  let out = []
  let buf = StringBuilder()
  let mut idx = 0
  for tok in tokens {
    if pred(tok.ttype) {
      if buf.to_string() != "" {
        out.push((idx, None, buf.to_string()))
        buf.reset()
      }
      out.push((tok.index, Some(tok.ttype), tok.value))
    } else {
      if buf.to_string() == "" {
        idx = tok.index
      }
      buf.write_string(tok.value)
    }
  }
  if buf.to_string() != "" {
    out.push((idx, None, buf.to_string()))
  }
  out
}

///|
/// Python's `_find_escape_tokens`: `Escape` tokens for the text between the
/// delimiters, `None` otherwise (an unmatched `left` is an `Error`).
fn find_escape_tokens(
  left : String,
  right : String,
  text : String,
) -> Array[(Int, @token.TokenType?, String)] {
  let out = []
  let mut index = 0
  let mut text = text
  while text != "" {
    let (a, sep1, rest) = partition(text, left)
    text = rest
    if a != "" {
      out.push((index, None, a))
      index += a.length()
    }
    if sep1 != "" {
      let (b, sep2, rest) = partition(text, right)
      text = rest
      if sep2 != "" {
        out.push((index + sep1.length(), Some(@token.escape), b))
        index += sep1.length() + b.length() + sep2.length()
      } else {
        out.push((index, Some(@token.error), sep1))
        index += sep1.length()
        text = b
      }
    }
  }
  out
}
