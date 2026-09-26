// Hand-written parts of pygments/lexers/rebol.py.

///|
let rebol_word_rules : Array[(@regex.Regex, @token.TokenType)] = [
  (@lexer.re(".*:$"), @token.generic_subheading),
  (
    @lexer.re(
      "(native|alias|all|any|as-string|as-binary|bind|bound\\?|case|catch|checksum|comment|debase|dehex|exclude|difference|disarm|either|else|enbase|foreach|remove-each|form|free|get|get-env|if|in|intersect|loop|minimum-of|maximum-of|mold|new-line|new-line\\?|not|now|prin|print|reduce|compose|construct|repeat|reverse|save|script\\?|set|shift|switch|throw|to-hex|trace|try|type\\?|union|unique|unless|unprotect|unset|until|use|value\\?|while|compress|decompress|secure|open|close|read|read-io|write-io|write|update|query|wait|input\\?|exp|log-10|log-2|log-e|square-root|cosine|sine|tangent|arccosine|arcsine|arctangent|protect|lowercase|uppercase|entab|detab|connected\\?|browse|launch|stats|get-modes|set-modes|to-local-file|to-rebol-file|encloak|decloak|create-link|do-browser|bind\\?|hide|draw|show|size-text|textinfo|offset-to-caret|caret-to-offset|local-request-file|rgb-to-hsv|hsv-to-rgb|crypt-strength\\?|dh-make-key|dh-generate-key|dh-compute-key|dsa-make-key|dsa-generate-key|dsa-make-signature|dsa-verify-signature|rsa-make-key|rsa-generate-key|rsa-encrypt)$",
    ),
    @token.name_builtin,
  ),
  (
    @lexer.re(
      "(add|subtract|multiply|divide|remainder|power|and~|or~|xor~|minimum|maximum|negate|complement|absolute|random|head|tail|next|back|skip|at|pick|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|last|path|find|select|make|to|copy\\*|insert|remove|change|poke|clear|trim|sort|min|max|abs|cp|copy)$",
    ),
    @token.name_function,
  ),
  (
    @lexer.re(
      "(error|source|input|license|help|install|echo|Usage|with|func|throw-on-error|function|does|has|context|probe|\\?\\?|as-pair|mod|modulo|round|repend|about|set-net|append|join|rejoin|reform|remold|charset|array|replace|move|extract|forskip|forall|alter|first+|also|take|for|forever|dispatch|attempt|what-dir|change-dir|clean-path|list-dir|dirize|rename|split-path|delete|make-dir|delete-dir|in-dir|confirm|dump-obj|upgrade|what|build-tag|process-source|build-markup|decode-cgi|read-cgi|write-user|save-user|set-user-name|protect-system|parse-xml|cvs-date|cvs-version|do-boot|get-net-info|desktop|layout|scroll-para|get-face|alert|set-face|uninstall|unfocus|request-dir|center-face|do-events|net-error|decode-url|parse-header|parse-header-date|parse-email-addrs|import-email|send|build-attach-body|resend|show-popup|hide-popup|open-events|find-key-face|do-face|viewtop|confine|find-window|insert-event-func|remove-event-func|inform|dump-pane|dump-face|flag-face|deflag-face|clear-fields|read-net|vbug|path-thru|read-thru|load-thru|do-thru|launch-thru|load-image|request-download|do-face-alt|set-font|set-para|get-style|set-style|make-face|stylize|choose|hilight-text|hilight-all|unlight-text|focus|scroll-drag|clear-face|reset-face|scroll-face|resize-face|load-stock|load-stock-block|notify|request|flash|request-color|request-pass|request-text|request-list|request-date|request-file|dbug|editor|link-relative-path|emailer|parse-error)$",
    ),
    @token.keyword_namespace,
  ),
  (
    @lexer.re(
      "(halt|quit|do|load|q|recycle|call|run|ask|parse|view|unview|return|exit|break)$",
    ),
    @token.name_exception,
  ),
  (@lexer.re("REBOL$"), @token.generic_heading),
  (@lexer.re("to-.*"), @token.keyword),
  (
    @lexer.re("(\\+|-|\\*|/|//|\\*\\*|and|or|xor|=\\?|=|==|<>|<|>|<=|>=)$"),
    @token.operator,
  ),
  (@lexer.re(".*\\?$"), @token.keyword),
  (@lexer.re(".*\\!$"), @token.keyword_type),
  (@lexer.re("'.*"), @token.name_variable_instance),
  (@lexer.re("#.*"), @token.name_label),
  (@lexer.re("%.*"), @token.name_decorator),
]

///|
let red_word_rules : Array[(@regex.Regex, @token.TokenType)] = [
  (@lexer.re(".*:$"), @token.generic_subheading),
  (
    @lexer.re(
      "(if|unless|either|any|all|while|until|loop|repeat|foreach|forall|func|function|does|has|switch|case|reduce|compose|get|set|print|prin|equal\\?|not-equal\\?|strict-equal\\?|lesser\\?|greater\\?|lesser-or-equal\\?|greater-or-equal\\?|same\\?|not|type\\?|stats|bind|union|replace|charset|routine)$",
    ),
    @token.name_builtin,
  ),
  (
    @lexer.re(
      "(make|random|reflect|to|form|mold|absolute|add|divide|multiply|negate|power|remainder|round|subtract|even\\?|odd\\?|and~|complement|or~|xor~|append|at|back|change|clear|copy|find|head|head\\?|index\\?|insert|length\\?|next|pick|poke|remove|reverse|select|sort|skip|swap|tail|tail\\?|take|trim|create|close|delete|modify|open|open\\?|query|read|rename|update|write)$",
    ),
    @token.name_function,
  ),
  (
    @lexer.re(
      "(yes|on|no|off|true|false|tab|cr|lf|newline|escape|slash|sp|space|null|none|crlf|dot|null-byte)$",
    ),
    @token.name_builtin_pseudo,
  ),
  (
    @lexer.re(
      "(#system-global|#include|#enum|#define|#either|#if|#import|#export|#switch|#default|#get-definition)$",
    ),
    @token.keyword_namespace,
  ),
  (
    @lexer.re(
      "(system|halt|quit|quit-return|do|load|q|recycle|call|run|ask|parse|raise-error|return|exit|break|alias|push|pop|probe|\\?\\?|spec-of|body-of|quote|forever)$",
    ),
    @token.name_exception,
  ),
  (
    @lexer.re(
      "(action\\?|block\\?|char\\?|datatype\\?|file\\?|function\\?|get-path\\?|zero\\?|get-word\\?|integer\\?|issue\\?|lit-path\\?|lit-word\\?|logic\\?|native\\?|op\\?|paren\\?|path\\?|refinement\\?|set-path\\?|set-word\\?|string\\?|unset\\?|any-struct\\?|none\\?|word\\?|any-series\\?)$",
    ),
    @token.keyword,
  ),
  (@lexer.re("(JNICALL|stdcall|cdecl|infix)$"), @token.keyword_namespace),
  (@lexer.re("to-.*"), @token.keyword),
  (
    @lexer.re(
      "(\\+|-\\*\\*|-|\\*\\*|//|/|\\*|and|or|xor|=\\?|===|==|=|<>|<=|>=|<<<|>>>|<<|>>|<|>%)$",
    ),
    @token.operator,
  ),
  (@lexer.re(".*\\!$"), @token.keyword_type),
  (@lexer.re("'.*"), @token.name_variable_instance),
  (@lexer.re("#.*"), @token.name_label),
  (@lexer.re("%.*"), @token.name_decorator),
  (@lexer.re(":.*"), @token.generic_subheading),
]

///|
/// The `word_callback` of `RebolLexer` / `RedLexer`: classifies a word by
/// the first rule that matches (`re.match`), else `Name.Variable`.
fn rebol_word_callback(
  rules : Array[(@regex.Regex, @token.TokenType)],
) -> @lexer.CallbackFn {
  (ctx, m, _) => {
    let word = m.matched()
    let mut ttype = @token.name_variable
    for rule in rules {
      if @lexer.matches(rule.0, word) {
        ttype = rule.1
        break
      }
    }
    ctx.emit(m.start(), ttype, word)
  }
}

///|
fn rebol_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    ("RebolLexer.word_callback", rebol_word_callback(rebol_word_rules)),
  ])
}

///|
fn red_lexer_callbacks(_lx : @lexer.Lexer) -> Map[String, @lexer.CallbackFn] {
  Map::from_array([
    ("RedLexer.word_callback", rebol_word_callback(red_word_rules)),
  ])
}

///|
let rebol_header_start_re : @regex.Regex = @lexer.re(
  "^\\s*REBOL\\s*\\[",
  flags=@regex.IGNORECASE,
)

///|
let rebol_header_re : @regex.Regex = @lexer.re(
  "\\s*REBOL\\s*\\[",
  flags=@regex.IGNORECASE,
)

///|
fn rebol_lexer_analyse(text : String) -> Double {
  if @lexer.matches(rebol_header_start_re, text) {
    1.0
  } else if @lexer.search(rebol_header_re, text) {
    0.5
  } else {
    0.0
  }
}
