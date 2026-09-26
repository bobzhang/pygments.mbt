// Ports of tests/test_rtf_formatter.py (`test_all_options` is covered byte
// for byte by the formatter oracle).

///|
let rtf_foot : String = "\\par\n}\n"

///|
fn format_rtf(
  t : String,
  options? : Map[String, String] = {},
  lexer? : String = "text",
  style? : @styles.Style,
) -> String raise {
  let tokens = @lexers.get_lexer_by_name(lexer).get_tokens(t)
  @formatters.rtf_formatter(options~, style?).format(tokens)
}

///|
/// The `\redR\greenG\blueB;` entries of the color table.
fn extract_color_table(rtf : String) -> Array[String] {
  rtf
  .split("\n")
  .filter(l => l.has_prefix("\\red"))
  .map(l => l.to_owned())
  .collect()
}

///|
fn rtf_color(hex : String) -> String {
  let h = if hex.has_prefix("#") { @pystr.slice(hex, 1) } else { hex }
  let channel = (i : Int) => {
    let digit = (c : Char) => {
      if c >= 'a' {
        c.to_int() - 'a'.to_int() + 10
      } else if c >= 'A' {
        c.to_int() - 'A'.to_int() + 10
      } else {
        c.to_int() - '0'.to_int()
      }
    }
    let cs = h.to_array()
    digit(cs[i]) * 16 + digit(cs[i + 1])
  }
  "\\red\{channel(0)}\\green\{channel(2)}\\blue\{channel(4)};"
}

///|
test "rtf header" {
  assert_true(format_rtf("").has_prefix("{\\rtf1\\ansi\\uc0"))
}

///|
test "rtf footer" {
  assert_true(format_rtf("").has_suffix(rtf_foot))
}

///|
test "ascii characters" {
  assert_true(format_rtf("a b c d ~").has_suffix("a b c d ~" + rtf_foot))
}

///|
test "escape characters" {
  assert_true(format_rtf("\\ {{").has_suffix("\\\\ \\{\\{" + rtf_foot))
}

///|
test "single characters" {
  assert_true(
    format_rtf("â € ¤ каждой").has_suffix(
      "{\\u226} {\\u8364} {\\u164} {\\u1082}{\\u1072}{\\u1078}{\\u1076}{\\u1086}{\\u1081}" +
      rtf_foot,
    ),
  )
}

///|
test "double characters" {
  assert_true(
    format_rtf("\u{1000} \u{d7a3} \u{2195} \u{2195}\u{fe0e} \u{2fa1b}").has_suffix(
      "{\\u4096} {\\u55203} {\\u8597} {\\u8597}{\\u65038} {\\u55422}{\\u56859}" +
      rtf_foot,
    ),
  )
}

///|
test "linenos all defaults" {
  assert_true(
    format_rtf("line1\nline2\n").has_suffix("line1\\par\nline2\\par\n}\n"),
  )
}

///|
test "linenos text" {
  let r = format_rtf("line1\nline2\n", options={
    "linenos": "True",
    "lineno_padding": "2",
  })
  assert_true(r.has_suffix("{\\cf1 1  }line1\\par\n{\\cf1 2  }line2\\par\n}\n"))
}

///|
test "linenos newline characters" {
  let r = format_rtf("line1\\nline2\n", options={
    "linenos": "True",
    "lineno_padding": "2",
  })
  assert_true(r.has_suffix("{\\cf1 1  }line1\\\\nline2\\par\n}\n"))
}

///|
test "linenos python" {
  let style = @styles.Style::new(
    [(@token.token, ""), (@token.string, "#00ff00"), (@token.name, "#0000ff")],
    name="rtf_formatter_test",
    line_number_color="#ff0000",
  )
  let r = format_rtf(
    "s = \"line1\\nline2\"\n",
    options={ "linenos": "True", "lineno_padding": "2" },
    lexer="python",
    style~,
  )
  assert_eq(
    r,
    (
      #|{\rtf1\ansi\uc0\deff0{\fonttbl{\f0\fmodern\fprq1\fcharset0;}}
      #|{\colortbl;
      #|\red255\green0\blue0;
      #|\red0\green255\blue0;
      #|\red0\green0\blue255;
      #|}
      #|\f0\sa0
      #|\dntblnsbdb
      #|{\cf1 1  }{\cf3 s} = {\cf2 "}{\cf2 line1}{\cf2 \\n}{\cf2 line2}{\cf2 "}\par
      #|}
      #|
    ),
  )
}

///|
test "linenos left padding" {
  let r = format_rtf("0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n", options={
    "linenos": "True",
    "lineno_padding": "2",
  })
  assert_true(r.has_suffix("{\\cf1  9  }8\\par\n{\\cf1 10  }9\\par\n}\n"))
}

///|
test "lineno padding" {
  let r = format_rtf("line1\nline2\n", options={
    "linenos": "True",
    "lineno_padding": "3",
  })
  assert_true(
    r.has_suffix("{\\cf1 1   }line1\\par\n{\\cf1 2   }line2\\par\n}\n"),
  )
}

///|
test "linenostep" {
  let r = format_rtf("line1\nline2\nline3\nline4\n", options={
    "linenos": "True",
    "linenostep": "2",
    "lineno_padding": "2",
  })
  assert_true(
    r.has_suffix(
      "{\\cf1    }line1\\par\n{\\cf1 2  }line2\\par\n{\\cf1    }line3\\par\n{\\cf1 4  }line4\\par\n}\n",
    ),
  )
}

///|
test "linenostart" {
  let r = format_rtf("line1\nline2\nline3\nline4\n", options={
    "linenos": "True",
    "linenostart": "3",
    "lineno_padding": "2",
  })
  assert_true(
    r.has_suffix(
      "{\\cf1 3  }line1\\par\n{\\cf1 4  }line2\\par\n{\\cf1 5  }line3\\par\n{\\cf1 6  }line4\\par\n}\n",
    ),
  )
}

///|
test "linenostart left padding" {
  let r = format_rtf("line1\nline2\nline3\n", options={
    "linenos": "True",
    "linenostart": "98",
    "lineno_padding": "2",
  })
  assert_true(
    r.has_suffix(
      "{\\cf1  98  }line1\\par\n{\\cf1  99  }line2\\par\n{\\cf1 100  }line3\\par\n}\n",
    ),
  )
}

///|
test "linenos hl lines" {
  let r = format_rtf("line1\nline2\nline3\n", options={
    "linenos": "True",
    "hl_lines": "2 3",
    "lineno_padding": "2",
  })
  assert_true(
    r.has_suffix(
      "{\\cf1 1  }line1\\par\n{\\highlight2 {\\cf1 2  }line2\\par}\n{\\highlight2 {\\cf1 3  }line3\\par}\n}\n",
    ),
  )
}

///|
test "linenos off hl lines" {
  let r = format_rtf("line1\nline2\nline3\n", options={
    "linenos": "False",
    "hl_lines": "2 3",
  })
  assert_true(
    r.has_suffix(
      "line1\\par\n{\\highlight1 line2\\par}\n{\\highlight1 line3\\par}\n}\n",
    ),
  )
}

///|
test "hl linenostart no lines highlighted" {
  let r = format_rtf("line11\nline12\nline13\n", options={
    "linenos": "False",
    "hl_lines": "2 3",
    "hl_linenostart": "True",
    "linenostart": "11",
  })
  assert_true(r.has_suffix("line11\\par\nline12\\par\nline13\\par\n}\n"))
}

///|
test "hl linenostart lines highlighted" {
  let r = format_rtf("line11\nline12\nline13\n", options={
    "linenos": "False",
    "hl_lines": "12 13",
    "hl_linenostart": "True",
    "linenostart": "11",
  })
  assert_true(
    r.has_suffix(
      "line11\\par\n{\\highlight1 line12\\par}\n{\\highlight1 line13\\par}\n}\n",
    ),
  )
}

///|
test "lineno color style specify hex" {
  let style = @styles.Style::new([], line_number_color="#123456")
  let r = format_rtf("line1\nline2\n", options={ "linenos": "True" }, style~)
  assert_eq(extract_color_table(r)[0], rtf_color("#123456"))
}

///|
test "lineno color style specify inherit" {
  let style = @styles.Style::new([], line_number_color="inherit")
  let r = format_rtf("line1\nline2\n", options={ "linenos": "True" }, style~)
  assert_eq(
    extract_color_table(r)[0],
    rtf_color(@styles.ansimap["ansibrightblack"]),
  )
}

///|
test "lineno color from cli option" {
  let style = @styles.Style::new([], line_number_color="#123456")
  let r = format_rtf(
    "line1\nline2\n",
    options={ "linenos": "True", "lineno_color": "112233" },
    style~,
  )
  assert_eq(extract_color_table(r)[0], rtf_color("112233"))
}

///|
test "hl color style" {
  let style = @styles.Style::new(
    [],
    line_number_color="#123456",
    highlight_color=Some("#abcdef"),
  )
  let r = format_rtf(
    "line1\nline2\n",
    options={ "linenos": "True", "lineno_padding": "2", "hl_lines": "1 2" },
    style~,
  )
  assert_eq(extract_color_table(r)[1], rtf_color("#abcdef"))
  assert_true(
    r.has_suffix(
      "{\\highlight2 {\\cf1 1  }line1\\par}\n{\\highlight2 {\\cf1 2  }line2\\par}\n}\n",
    ),
  )
}

///|
test "hl color style no linenos" {
  let style = @styles.Style::new(
    [],
    line_number_color="#123456",
    highlight_color=Some("#abcdef"),
  )
  let r = format_rtf(
    "line1\nline2\n",
    options={ "linenos": "False", "hl_lines": "1 2" },
    style~,
  )
  assert_eq(extract_color_table(r)[0], rtf_color("#abcdef"))
  assert_true(
    r.has_suffix("{\\highlight1 line1\\par}\n{\\highlight1 line2\\par}\n}\n"),
  )
}

///|
test "hl color option" {
  let style = @styles.Style::new(
    [],
    line_number_color="#123456",
    highlight_color=Some("#abcdef"),
  )
  let r = format_rtf(
    "line1\nline2\n",
    options={ "linenos": "False", "hl_lines": "1 2", "hl_color": "aabbcc" },
    style~,
  )
  assert_eq(extract_color_table(r)[0], rtf_color("aabbcc"))
  assert_true(
    r.has_suffix("{\\highlight1 line1\\par}\n{\\highlight1 line2\\par}\n}\n"),
  )
}
