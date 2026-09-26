// Hand-written parts of pygments/lexers/webmisc.py.

///|
/// Emits groups 1-3 of `m` at the start of the match with the given types
/// (the XQuery callbacks yield every group at `match.start()`).
fn xquery_emit3(
  ctx : @lexer.Ctx,
  m : @regex.Match,
  t1 : @token.TokenType,
  t2 : @token.TokenType,
  t3 : @token.TokenType,
) -> Unit {
  ctx.emit(m.start(), t1, m.group(1).unwrap_or(""))
  ctx.emit(m.start(), t2, m.group(2).unwrap_or(""))
  ctx.emit(m.start(), t3, m.group(3).unwrap_or(""))
}

///|
/// Callbacks of `XQueryLexer` (an `ExtendedRegexLexer`). Python keeps the
/// parser state stack `xquery_parse_state` in a class attribute; here it is
/// per-run state, reset for every tokenization.
fn x_query_lexer_callbacks(
  _lx : @lexer.Lexer,
) -> Map[String, @lexer.CallbackFn] {
  let parse_state : Array[String] = []
  let pop_parse_state = () => {
    match parse_state.pop() {
      Some(s) => s
      None => fail("pop from empty list")
    }
  }
  // `ctx.stack = ['root']`, emitting group 1 with `ttype`
  let to_root = (ttype : @token.TokenType) => {
    (ctx : @lexer.Ctx, m : @regex.Match, _ : Array[@lexer.CallbackArg]) => {
      ctx.emit(m.start(), ttype, m.group(1).unwrap_or(""))
      ctx.set_state_stack(["root"])
      ctx.pos = m.end()
    }
  }
  // emits group 1 with `ttype`, pushes `parse` on the parse state and
  // `state` on the lexer stack
  let push1 = (ttype : @token.TokenType, state : String, parse : String) => {
    (ctx : @lexer.Ctx, m : @regex.Match, _ : Array[@lexer.CallbackArg]) => {
      ctx.emit(m.start(), ttype, m.group(1).unwrap_or(""))
      ctx.push_state(state)
      parse_state.push(parse)
      ctx.pos = m.end()
    }
  }
  // emits groups 1-3, pushes `parse` on the parse state and `state` on the
  // lexer stack
  let push3 = (
    t1 : @token.TokenType,
    t3 : @token.TokenType,
    state : String,
    parse : String,
  ) => {
    (ctx : @lexer.Ctx, m : @regex.Match, _ : Array[@lexer.CallbackArg]) => {
      xquery_emit3(ctx, m, t1, @token.whitespace, t3)
      parse_state.push(parse)
      ctx.push_state(state)
      ctx.pos = m.end()
    }
  }
  // emits groups 1-3, resets the lexer stack to root and pushes `operator`
  // on the parse state
  let operator_root3 = (t3 : @token.TokenType) => {
    (ctx : @lexer.Ctx, m : @regex.Match, _ : Array[@lexer.CallbackArg]) => {
      xquery_emit3(ctx, m, @token.keyword, @token.whitespace, t3)
      ctx.set_state_stack(["root"])
      parse_state.push("operator")
      ctx.pos = m.end()
    }
  }
  Map::from_array([
    ("XQueryLexer.punctuation_root_callback", to_root(@token.punctuation)),
    ("XQueryLexer.operator_root_callback", to_root(@token.operator)),
    (
      "XQueryLexer.popstate_tag_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.name_tag, m.group(1).unwrap_or(""))
        if parse_state.pop() is Some(s) {
          ctx.push_state(s)
        }
        ctx.pos = m.end()
      },
    ),
    (
      "XQueryLexer.popstate_xmlcomment_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.string_doc, m.group(1).unwrap_or(""))
        ctx.push_state(pop_parse_state())
        ctx.pos = m.end()
      },
    ),
    (
      "XQueryLexer.popstate_kindtest_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.punctuation, m.group(1).unwrap_or(""))
        let next_state = pop_parse_state()
        if next_state == "occurrenceindicator" {
          let g2 = m.group(2).unwrap_or("")
          if g2.length() > 0 && g2.iter().all(c => c is ('?' | '*' | '+')) {
            // `re.match("[?*+]+", group(2))`: group 2 is `[*+?]?`
            ctx.emit(m.start(), @token.punctuation, g2)
            ctx.push_state("operator")
            ctx.pos = m.end()
          } else {
            ctx.push_state("operator")
            ctx.pos = m.end(group=1)
          }
        } else {
          ctx.push_state(next_state)
          ctx.pos = m.end(group=1)
        }
      },
    ),
    (
      "XQueryLexer.popstate_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.punctuation, m.group(1).unwrap_or(""))
        // if we have run out of our state stack, pop whatever is on the
        // pygments state stack
        if parse_state.is_empty() {
          ignore(ctx.stack.pop())
          if ctx.stack.is_empty() {
            // make sure we have at least the root state on invalid inputs
            ctx.set_state_stack(["root"])
          }
        } else if ctx.stack.length() > 1 {
          ctx.push_state(pop_parse_state())
        } else {
          // default back to root
          ctx.set_state_stack(["root"])
        }
        ctx.pos = m.end()
      },
    ),
    (
      "XQueryLexer.pushstate_element_content_starttag_callback",
      push1(@token.name_tag, "start_tag", "element_content"),
    ),
    (
      "XQueryLexer.pushstate_operator_order_callback",
      operator_root3(@token.punctuation),
    ),
    (
      "XQueryLexer.pushstate_operator_map_callback",
      operator_root3(@token.punctuation),
    ),
    (
      "XQueryLexer.pushstate_operator_root_validate",
      operator_root3(@token.punctuation),
    ),
    (
      "XQueryLexer.pushstate_operator_root_validate_withmode",
      operator_root3(@token.keyword),
    ),
    (
      "XQueryLexer.pushstate_operator_processing_instruction_callback",
      push1(@token.string_doc, "processing_instruction", "operator"),
    ),
    (
      "XQueryLexer.pushstate_element_content_processing_instruction_callback",
      push1(@token.string_doc, "processing_instruction", "element_content"),
    ),
    (
      "XQueryLexer.pushstate_element_content_cdata_section_callback",
      push1(@token.string_doc, "cdata_section", "element_content"),
    ),
    (
      "XQueryLexer.pushstate_operator_cdata_section_callback",
      push1(@token.string_doc, "cdata_section", "operator"),
    ),
    (
      "XQueryLexer.pushstate_element_content_xmlcomment_callback",
      push1(@token.string_doc, "xml_comment", "element_content"),
    ),
    (
      "XQueryLexer.pushstate_operator_xmlcomment_callback",
      push1(@token.string_doc, "xml_comment", "operator"),
    ),
    (
      "XQueryLexer.pushstate_kindtest_callback",
      push3(@token.keyword, @token.punctuation, "kindtest", "kindtest"),
    ),
    (
      "XQueryLexer.pushstate_operator_kindtestforpi_callback",
      push3(@token.keyword, @token.punctuation, "kindtestforpi", "operator"),
    ),
    (
      "XQueryLexer.pushstate_operator_kindtest_callback",
      push3(@token.keyword, @token.punctuation, "kindtest", "operator"),
    ),
    (
      "XQueryLexer.pushstate_occurrenceindicator_kindtest_callback",
      push3(
        @token.name_tag, @token.punctuation, "kindtest", "occurrenceindicator",
      ),
    ),
    (
      "XQueryLexer.pushstate_operator_starttag_callback",
      push1(@token.name_tag, "start_tag", "operator"),
    ),
    (
      "XQueryLexer.pushstate_operator_root_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.punctuation, m.group(1).unwrap_or(""))
        parse_state.push("operator")
        ctx.set_state_stack(["root"])
        ctx.pos = m.end()
      },
    ),
    (
      "XQueryLexer.pushstate_operator_root_construct_callback",
      operator_root3(@token.punctuation),
    ),
    (
      "XQueryLexer.pushstate_root_callback",
      (ctx, m, _) => {
        ctx.emit(m.start(), @token.punctuation, m.group(1).unwrap_or(""))
        let cur_state = ctx.top_state()
        ignore(ctx.stack.pop())
        parse_state.push(cur_state)
        ctx.set_state_stack(["root"])
        ctx.pos = m.end()
      },
    ),
  ])
}

///|
fn slim_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  css_indentation_callbacks()
}
