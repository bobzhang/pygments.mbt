///|
/// Python's `%`-formatting with a mapping: `%(key)s` is replaced by
/// `values[key]` and `%%` by `%`.
fn percent_format(template : String, values : Map[String, String]) -> String {
  let buf = StringBuilder()
  let n = template.length()
  let mut i = 0
  while i < n {
    let c = template.unsafe_get(i)
    if c.to_int() == '%'.to_int() && i + 1 < n {
      let d = template.unsafe_get(i + 1)
      if d.to_int() == '%'.to_int() {
        buf.write_char('%')
        i += 2
        continue
      }
      if d.to_int() == '('.to_int() {
        match template.view(start_offset=i + 2).find(")s") {
          Some(j) => {
            let key = template.unsafe_substring(start=i + 2, end=i + 2 + j)
            buf.write_string(values.get(key).unwrap_or(""))
            i = i + 2 + j + 2
            continue
          }
          None => ()
        }
      }
    }
    buf.write_char(c.to_int().unsafe_to_char())
    i += 1
  }
  buf.to_string()
}

///|
/// Python's `latex.STYLE_TEMPLATE`.
let latex_style_template : String =
  #|
  #|\makeatletter
  #|\def\%(cp)s@reset{\let\%(cp)s@it=\relax \let\%(cp)s@bf=\relax%%
  #|    \let\%(cp)s@ul=\relax \let\%(cp)s@tc=\relax%%
  #|    \let\%(cp)s@bc=\relax \let\%(cp)s@ff=\relax}
  #|\def\%(cp)s@tok#1{\csname %(cp)s@tok@#1\endcsname}
  #|\def\%(cp)s@toks#1+{\ifx\relax#1\empty\else%%
  #|    \%(cp)s@tok{#1}\expandafter\%(cp)s@toks\fi}
  #|\def\%(cp)s@do#1{\%(cp)s@bc{\%(cp)s@tc{\%(cp)s@ul{%%
  #|    \%(cp)s@it{\%(cp)s@bf{\%(cp)s@ff{#1}}}}}}}
  #|\def\%(cp)s#1#2{\%(cp)s@reset\%(cp)s@toks#1+\relax+\%(cp)s@do{#2}}
  #|
  #|%(styles)s
  #|
  #|\def\%(cp)sZbs{\char`\\}
  #|\def\%(cp)sZus{\char`\_}
  #|\def\%(cp)sZob{\char`\{}
  #|\def\%(cp)sZcb{\char`\}}
  #|\def\%(cp)sZca{\char`\^}
  #|\def\%(cp)sZam{\char`\&}
  #|\def\%(cp)sZlt{\char`\<}
  #|\def\%(cp)sZgt{\char`\>}
  #|\def\%(cp)sZsh{\char`\#}
  #|\def\%(cp)sZpc{\char`\%%}
  #|\def\%(cp)sZdl{\char`\$}
  #|\def\%(cp)sZhy{\char`\-}
  #|\def\%(cp)sZsq{\char`\'}
  #|\def\%(cp)sZdq{\char`\"}
  #|\def\%(cp)sZti{\char`\~}
  #|%% for compatibility with earlier versions
  #|\def\%(cp)sZat{@}
  #|\def\%(cp)sZlb{[}
  #|\def\%(cp)sZrb{]}
  #|\makeatother
  #|

///|
/// Python's `latex.DOC_TEMPLATE`.
let latex_doc_template : String =
  #|
  #|\documentclass{%(docclass)s}
  #|\usepackage{fancyvrb}
  #|\usepackage{color}
  #|\usepackage[%(encoding)s]{inputenc}
  #|%(preamble)s
  #|
  #|%(styledefs)s
  #|
  #|\begin{document}
  #|
  #|\section*{%(title)s}
  #|
  #|%(code)s
  #|\end{document}
  #|
