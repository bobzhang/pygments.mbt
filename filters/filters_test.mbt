// Ports of `TestFilters` in tests/test_basic_api.py.

///|
let filter_test_text : String =
  #|import os
  #|from pygments import lexers
  #|
  #|class Foo(object):
  #|    """Docstring. API: see TODO"""
  #|    def method(self, x):
  #|	if isinstance(x, lexers.Lexer):  # tab-indented
  #|	    return x  # API: returns x
  #|        return "\<alpha>"
  #|

///|
fn python_with_filter(
  name : String,
  options : Map[String, String],
) -> @lexer.Lexer raise {
  let lx = @lexers.get_lexer_by_name("python")
  lx.add_filter(@filters.get_filter_by_name(name, options~))
  lx
}

///|
test "basic" {
  let filters_args : Array[(String, Map[String, String])] = [
    ("whitespace", { "spaces": "True", "tabs": "True", "newlines": "True" }),
    ("whitespace", { "wstokentype": "False", "spaces": "True" }),
    ("highlight", { "names": "isinstance lexers x" }),
    ("codetagify", { "codetags": "API" }),
    ("keywordcase", { "case": "capitalize" }),
    ("raiseonerror", {}),
    ("gobble", { "n": "4" }),
    ("tokenmerge", {}),
    ("symbols", { "lang": "isabelle" }),
  ]
  for entry in filters_args {
    let (name, options) = entry
    let tokens = python_with_filter(name, options).get_tokens(filter_test_text)
    let roundtext = tokens.map(t => t.1).join("")
    if !["whitespace", "keywordcase", "gobble", "symbols"].contains(name) {
      assert_eq(roundtext, filter_test_text)
    }
  }
}

///|
test "raiseonerror" {
  let lx = python_with_filter("raiseonerror", {})
  let raised = try lx.get_tokens("$") catch {
    @filters.ErrorToken(v) => v == "$"
    _ => false
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "whitespace" {
  let lx = python_with_filter("whitespace", { "spaces": "%" })
  let text = lx.get_tokens(filter_test_text).map(t => t.1).join("")
  assert_true(!text.contains(" "))
}

///|
test "keywordcase" {
  let lx = python_with_filter("keywordcase", { "case": "capitalize" })
  let text = lx.get_tokens(filter_test_text).map(t => t.1).join("")
  assert_true(text.contains("Def") && text.contains("Class"))
}

///|
test "codetag" {
  let lx = python_with_filter("codetagify", {})
  let tokens = lx.get_tokens("# BUG: text")
  assert_eq(tokens[0].1, "# ")
  assert_eq(tokens[1].1, "BUG")
  assert_eq(tokens[1].0, @token.comment_special)
}

///|
test "codetag boundary" {
  let lx = python_with_filter("codetagify", {})
  let tokens = lx.get_tokens("# DEBUG: text")
  assert_eq(tokens[0].1, "# DEBUG: text")
}

///|
test "symbols" {
  let lx = @lexers.get_lexer_by_name("isabelle")
  lx.add_filter(@filters.get_filter_by_name("symbols"))
  let tokens = lx.get_tokens("lemma \"A \\<Longrightarrow> B\"")
  assert_eq(tokens[0].1, "lemma")
  assert_eq(tokens[3].1, "A ")
  assert_eq(tokens[4].1, "\u{27f9}")
}

///|
test "unknown filter" {
  let msg = try @filters.get_filter_by_name("nope") catch {
    @filters.ClassNotFound(m) => m
    _ => "other"
  } noraise {
    _ => "none"
  }
  inspect(msg, content="filter 'nope' not found")
}

///|
test "get_all_filters" {
  inspect(
    @filters.get_all_filters().join(" "),
    content="codetagify keywordcase highlight raiseonerror whitespace gobble tokenmerge symbols",
  )
}
