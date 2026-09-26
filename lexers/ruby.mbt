// Hand-written parts of pygments/lexers/ruby.py.

///|
/// Per-run heredoc stacks. Python keeps one list per `LexerContext`
/// (`ctx.__dict__.setdefault('heredocstack', [])`); contexts are told apart
/// by identity.
priv struct HeredocStacks {
  entries : Array[(@lexer.Ctx, Array[(Bool, String)])]
}

///|
fn HeredocStacks::get(
  self : HeredocStacks,
  ctx : @lexer.Ctx,
) -> Array[(Bool, String)] {
  for e in self.entries {
    if physical_equal(e.0, ctx) {
      return e.1
    }
  }
  let st = []
  self.entries.push((ctx, st))
  st
}

///|
/// `RubyLexer.heredoc_callback` / `CrystalLexer.heredoc_callback`.
/// Groups: 1 = `<<[-~]?`, 2 = quote, 3 = name, 4 = quote, 5 = rest of line.
/// `tolerant_ops` are the operators allowing an indented terminator;
/// `skip_unterminated` advances past the lines of an unterminated heredoc
/// (Ruby does, Crystal does not).
fn heredoc_callback(
  stacks : HeredocStacks,
  ctx : @lexer.Ctx,
  m : @regex.Match,
  tolerant_ops : Array[String],
  skip_unterminated : Bool,
) -> Unit raise {
  let g = (i : Int) => m.group(i).unwrap_or("")
  ctx.emit(m.start(group=1), @token.operator, g(1))
  ctx.emit(m.start(group=2), @token.string_heredoc, g(2))
  ctx.emit(m.start(group=3), @token.string_delimiter, g(3))
  ctx.emit(m.start(group=4), @token.string_heredoc, g(4))
  let heredocstack = stacks.get(ctx)
  let outermost = heredocstack.is_empty()
  heredocstack.push((tolerant_ops.contains(g(1)), g(3)))
  ctx.pos = m.start(group=5)
  ctx.end = m.end(group=5)
  // this may find other heredocs, so limit the recursion depth
  if heredocstack.length() < 100 {
    @lexer.run_context(ctx)
  } else {
    ctx.emit(ctx.pos, @token.string_heredoc, g(5))
  }
  ctx.pos = m.end()
  if outermost {
    // this is the outer heredoc again, now we can process them all
    for entry in heredocstack {
      let (tolerant, hdname) = entry
      let lines : Array[(Int, String)] = []
      let mut found = false
      for line_entry in pystr_lines(pystr_from(ctx.text, ctx.pos)) {
        let start = line_entry.0 + ctx.pos
        let line = line_entry.1
        let check = if tolerant {
          pystr_strip(line)
        } else {
          pystr_rstrip(line)
        }
        if check == hdname {
          for l in lines {
            ctx.emit(l.0, @token.string_heredoc, l.1)
          }
          ctx.emit(start, @token.string_delimiter, line)
          ctx.pos = start + line.length()
          found = true
          break
        }
        lines.push((start, line))
      }
      if !found {
        // end of heredoc not found -- error!
        for l in lines {
          ctx.emit(l.0, @token.error, l.1)
        }
        if skip_unterminated && !lines.is_empty() {
          let last = lines[lines.length() - 1]
          ctx.pos = last.0 + last.1.length()
        }
      }
    }
    ctx.end = ctx.text.length()
    heredocstack.clear()
  }
}

///|
/// `intp_regex_callback` / `intp_string_callback` of
/// `gen_rubystrings_rules`: lexes group 3 in `state` with a fresh context.
fn ruby_intp_callback(
  ctx : @lexer.Ctx,
  m : @regex.Match,
  delim : @token.TokenType,
  state : String,
) -> Unit raise {
  ctx.emit(m.start(group=1), delim, m.group(1).unwrap_or(""))
  let inner = m.group(3).unwrap_or("")
  let nctx = @lexer.Ctx::new(
    ctx.lexer,
    ctx.def,
    inner,
    callbacks=ctx.callbacks,
    stack=[state],
  )
  @lexer.run_context(nctx)
  let offset = m.start(group=3)
  for t in nctx.out {
    ctx.emit(t.index + offset, t.ttype, t.value)
  }
  ctx.emit(m.start(group=4), delim, m.group(4).unwrap_or(""))
  ctx.pos = m.end()
}

///|
fn ruby_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  let stacks : HeredocStacks = { entries: [], }
  {
    "RubyLexer.heredoc_callback": (ctx, m, _) => {
      heredoc_callback(stacks, ctx, m, ["<<-", "<<~"], true)
    },
    "RubyLexer.gen_rubystrings_rules.intp_regex_callback": (ctx, m, _) => {
      ruby_intp_callback(ctx, m, @token.string_regex, "interpolated-regex")
    },
    "RubyLexer.gen_rubystrings_rules.intp_string_callback": (ctx, m, _) => {
      ruby_intp_callback(ctx, m, @token.string_other, "interpolated-string")
    },
  }
}

///|
fn ruby_lexer_analyse(text : String) -> Double {
  if @lexer.shebang_matches(text, "ruby(1\\.\\d)?") {
    1.0
  } else {
    0.0
  }
}

///|
let ruby_console_prompt_re : @regex.Regex = @lexer.re(
  "irb\\([a-zA-Z_]\\w*\\):\\d{3}:\\d+[>*\"'] |>> |\\?> ",
)

///|
/// `RubyConsoleLexer.get_tokens_unprocessed`.
fn ruby_console_lexer_tokenizer(
  lx : @lexer.Lexer,
  text : String,
  _stack : Array[String],
) -> Array[@lexer.Token] raise {
  let rblexer = ruby_lexer(options=lx.options)
  let out : Array[@lexer.Token] = []
  let mut curcode = ""
  let mut insertions : Array[(Int, Array[@lexer.Token])] = []
  for entry in pystr_lines(text) {
    let (start, line) = entry
    match ruby_console_prompt_re.match_at(line, 0) {
      Some(m) => {
        let end = m.end()
        insertions.push(
          (
            curcode.length(),
            [pystr_itok(@token.generic_prompt, @lexer.py_slice(line, 0, end))],
          ),
        )
        curcode = curcode + pystr_from(line, end)
      }
      None => {
        if curcode != "" {
          out.append(
            @lexer.do_insertions(
              insertions,
              rblexer.get_tokens_unprocessed(curcode),
            ),
          )
          curcode = ""
          insertions = []
        }
        out.push({ index: start, ttype: @token.generic_output, value: line, })
      }
    }
  }
  if curcode != "" {
    out.append(
      @lexer.do_insertions(insertions, rblexer.get_tokens_unprocessed(curcode)),
    )
  }
  out
}
