"""Build the formatter/style/filter conformance corpus from Python.

Every formatter is fed a *stored* token stream (so the MoonBit side does not
depend on lexer correctness) with several option sets and styles; the
expected output is recorded byte for byte. Also recorded: `get_style_defs`
for many styles/arguments, the processed per-token style dictionaries of
every builtin style, and filter outputs.

Output: JSON lines (default `.oracle/formatters.jsonl`), in this order:
  {"kind": "tokens", "key", "tokens": [[ttype, value], ...]}
  {"kind": "style", "name", "attrs": {...}, "entries": [[ttype, {...}], ...]}
  {"kind": "format", "id", "formatter", "options", "tokens", "output"|"error"}
  {"kind": "styledefs", "id", "formatter", "options", "arg"|"args", "output"|"error"}
  {"kind": "filter", "id", "filter", "options", "tokens", "output"|"error"}

Usage: python3 scripts/formatter_oracle.py [out.jsonl]
"""
import io
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PYG = os.path.join(ROOT, '.repos', 'pygments')
sys.path.insert(0, PYG)

from pygments.formatters import get_formatter_by_name  # noqa: E402
from pygments.filters import get_filter_by_name, get_all_filters  # noqa: E402
from pygments.lexers import get_lexer_by_name  # noqa: E402
from pygments.styles import get_all_styles, get_style_by_name  # noqa: E402
from pygments.token import Token  # noqa: E402

OUT_PATH = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '.oracle', 'formatters.jsonl')
out = open(OUT_PATH, 'w')


def emit(obj):
    out.write(json.dumps(obj, ensure_ascii=False) + '\n')


def ser(tokens):
    return [[str(t), v] for t, v in tokens]


# ---------------------------------------------------------------------------
# token streams

BASIC = '''\


# -*- coding: utf-8 -*-
"""Docstring with <html> & "quotes" and 'single' TODO: fix."""
import os  # NOTE: comment with $math$ and |esc| and ~^_#%{}\\

def f(x, y=1):
\tif x > y and not x < 0:
\t\treturn "café 中文 \U0001F600\\n"   # XXX trailing
    return [i ** 2 for i in range(10)]  -  y

class Foo(object):
    @property
    def bar(self): return 0x1F + 3.5e-2 - 'it\\'s'
'''

tokens_sets = {}


def add_lexed(key, alias, text, max_lines=None):
    if max_lines is not None:
        text = ''.join(text.splitlines(True)[:max_lines])
    tokens_sets[key] = list(get_lexer_by_name(alias).get_tokens(text))


add_lexed('basic', 'python', BASIC)
add_lexed('nonl', 'python', 'x = 1  # no newline at the end')
tokens_sets['nonl'][-1:] = []  # drop the newline ensured by the lexer
add_lexed('pycon', 'pycon', '>>> 1 / 0\nTraceback (most recent call last):\n  File "<stdin>", line 1, in <module>\nZeroDivisionError: division by zero\n>>> print("ok")\nok\n')
add_lexed('diff', 'diff', '--- a/x\n+++ b/x\n@@ -1,3 +1,3 @@\n context\n-old line\n+new line\n')
add_lexed('long', 'python', 'value = some_function_name(argument_one, argument_two) + another_call(x)\nshort = 1\n' + 'z' * 25 + '\n')
tokens_sets['empty'] = []
tokens_sets['custom'] = [
    (Token.Name.Builtin.Magic, 'magic'),
    (Token.Text, ' '),
    (Token.Comment.Single.Special2, '# custom\n'),
    (Token.Keyword.Constant, 'None'),
    (Token.Text.Whitespace, '\n\n'),
    (Token.Error, '$'),
    (Token.Generic.Heading, 'Heading'),
    (Token.Escape, '\\textbf{x}'),
    (Token, 'root token\n'),
    (Token.Literal.String.Doc, '"""TODO: BUG here"""'),
    (Token.Operator.Word, 'and'),
    (Token.Name, 'x\r\ny\x0cz'),
    (Token.Text, '\n'),
]
tokens_sets['toplevel'] = [
    (Token.Foo, 'foo'),
    (Token.Foo.Bar, ' bar\n'),
]

EXAMPLES = [
    ('ex_unicodedoc', 'python', 'python/unicodedoc.py', None),
    ('ex_c', 'c', 'c/example.c', 60),
    ('ex_html', 'html', 'html/test.html', 40),
    ('ex_js', 'js', 'js/unicode.js', None),
    ('ex_css', 'css', 'css/webkit-transition.css', None),
    ('ex_rb', 'rb', 'rb/example.rb', 60),
]
for key, alias, rel, max_lines in EXAMPLES:
    path = os.path.join(PYG, 'tests', 'examplefiles', rel)
    if not os.path.exists(path):
        print('missing example', rel)
        continue
    with open(path, encoding='utf-8') as f:
        add_lexed(key, alias, f.read(), max_lines)

for key, toks in tokens_sets.items():
    emit({'kind': 'tokens', 'key': key, 'tokens': ser(toks)})

# ---------------------------------------------------------------------------
# styles

for name in get_all_styles():
    st = get_style_by_name(name)
    attrs = {a: getattr(st, a) for a in (
        'name', 'background_color', 'highlight_color', 'line_number_color',
        'line_number_background_color', 'line_number_special_color',
        'line_number_special_background_color', 'web_style_gallery_exclude')}
    attrs['aliases'] = list(st.aliases)
    emit({'kind': 'style', 'name': name, 'attrs': attrs,
          'entries': [[str(t), d] for t, d in st]})

# ---------------------------------------------------------------------------
# formatter outputs

STYLES = ['default', 'monokai', 'bw', 'solarized-dark', 'abap', 'rrt']
T = 'True'
OPTION_SETS = {
    'html': [
        {}, {'noclasses': T}, {'linenos': 'table'}, {'linenos': 'inline'},
        {'linenos': 'table', 'linenostart': '5', 'linenostep': '2',
         'linenospecial': '3', 'anchorlinenos': T, 'lineanchors': 'ln'},
        {'linenos': 'inline', 'noclasses': T, 'linenospecial': '2'},
        {'linenos': 'inline', 'anchorlinenos': T, 'linespans': 'L', 'linenostart': '-8'},
        {'hl_lines': '1 3 x', 'noclasses': T}, {'hl_lines': '2 4'},
        {'full': T, 'title': 'T<&>'}, {'full': T, 'cssfile': 'x.css', 'encoding': 'utf-8'},
        {'nowrap': T}, {'nowrap': T, 'linenos': 'inline', 'hl_lines': '1'},
        {'classprefix': 'pre-', 'cssclass': 'code', 'cssstyles': 'border: 1px "x"',
         'prestyles': 'margin: 0'},
        {'wrapcode': T, 'filename': 'a&b.py'}, {'linenos': 'table', 'filename': 'f.py'},
        {'linespans': 'sp', 'lineseparator': '<br>'}, {'debug_token_types': T},
        {'nobackground': T, 'noclasses': T}, {'cssclass': ''},
        {'linenos': 'inline', 'hl_lines': '2', 'lineanchors': 'a', 'linespans': 's',
         'wrapcode': T},
        {'linenos': 'table', 'hl_lines': '1 2', 'noclasses': T, 'linenospecial': '1'},
    ],
    'terminal': [{}, {'bg': 'dark'}, {'linenos': T}],
    'terminal256': [{}, {'linenos': T}, {'nobold': T, 'noitalic': T, 'nounderline': T}],
    'terminal16m': [{}, {'linenos': T}, {'nobold': T}],
    'latex': [
        {}, {'full': T, 'title': 'T'}, {'linenos': T, 'linenostart': '3', 'linenostep': '2'},
        {'nowrap': T}, {'texcomments': T}, {'mathescape': T}, {'escapeinside': '||'},
        {'escapeinside': '$$'}, {'commandprefix': 'PZ', 'envname': 'BVerbatim',
                                 'verboptions': 'frame=single'},
        {'full': T, 'docclass': 'report', 'preamble': '\\usepackage{x}',
         'encoding': 'utf-8'},
        {'linenos': T, 'linenostart': '0', 'linenostep': '0'},
    ],
    'rtf': [
        {}, {'linenos': T},
        {'linenos': T, 'lineno_fontsize': '10', 'fontsize': '24', 'lineno_padding': '3',
         'linenostart': '3', 'linenostep': '2'},
        {'hl_lines': '1 2', 'hl_color': '#ff0000'},
        {'hl_lines': '3', 'hl_linenostart': T, 'linenostart': '2', 'linenos': T,
         'lineno_color': '00ff00'},
        {'fontface': 'Courier {New}'},
    ],
    'svg': [
        {}, {'linenos': T}, {'nowrap': T},
        {'spacehack': 'False', 'fontsize': '12px', 'fontfamily': 'x', 'xoffset': '3',
         'yoffset': '4', 'ystep': '20'},
        {'linenos': T, 'linenostart': '3', 'linenostep': '2', 'linenowidth': '50'},
        {'encoding': 'utf-8', 'fontsize': 'big'},
    ],
    'bbcode': [{}, {'codetag': T, 'monofont': T}, {'monofont': T}],
    'irc': [{}, {'bg': 'dark'}, {'linenos': T}],
    'groff': [{}, {'monospaced': 'False'}, {'linenos': T}, {'wrap': '10'},
              {'wrap': '7', 'linenos': T}],
    'pango': [{}],
    'raw': [{}, {'error_color': 'brightred'}, {'compress': 'none'}],
    'testcase': [{}],
    'text': [{}],
}
STYLED = {'html', 'terminal256', 'terminal16m', 'latex', 'rtf', 'svg', 'bbcode',
          'groff', 'pango'}
FULL_MATRIX_TOKENS = ['basic', 'custom', 'nonl', 'empty']


def run_format(alias, options, tokens):
    fmt = get_formatter_by_name(alias, **options)
    if fmt.encoding:
        buf = io.BytesIO()
        fmt.format(tokens, buf)
        return buf.getvalue().decode(fmt.encoding)
    buf = io.StringIO()
    fmt.format(tokens, buf)
    return buf.getvalue()


case_id = 0


def record(kind, fields, thunk):
    global case_id
    case_id += 1
    obj = {'kind': kind, 'id': case_id}
    obj.update(fields)
    try:
        obj['output'] = thunk()
    except Exception as e:  # noqa: BLE001
        obj['error'] = type(e).__name__ + ': ' + str(e)
    emit(obj)


tmp = tempfile.mkdtemp()
os.chdir(tmp)  # the HTML `cssfile` option writes a file next to the output
devnull = open(os.devnull, 'w')
real_stderr = sys.stderr
sys.stderr = devnull  # "Note: Cannot determine output file name, ..."

for alias, option_sets in OPTION_SETS.items():
    styles = STYLES if alias in STYLED else ['default']
    for oi, options in enumerate(option_sets):
        if oi == 0:
            keys = list(tokens_sets)
            use_styles = styles
        else:
            keys = FULL_MATRIX_TOKENS
            use_styles = styles[:2]
        for style in use_styles:
            for key in keys:
                opts = dict(options)
                if style != 'default':
                    opts['style'] = style
                record('format', {'formatter': alias, 'options': opts, 'tokens': key},
                       lambda: run_format(alias, opts, tokens_sets[key]))

# get_style_defs
for alias in ['html', 'latex', 'terminal', 'rtf', 'text']:
    style_names = list(get_all_styles()) if alias in ('html', 'latex') else ['default']
    for style in style_names:
        for arg in ([None, '', 'body', '.x'] if alias == 'html' else [None, '']):
            opts = {'style': style}
            fields = {'formatter': alias, 'options': opts}
            if arg is not None:
                fields['arg'] = arg
            record('styledefs', fields,
                   lambda: get_formatter_by_name(alias, **opts).get_style_defs(
                       *([] if arg is None else [arg])))
for opts in [{'cssclass': 'c'}, {'classprefix': 'p-'}, {'nobackground': T},
             {'cssclass': ''}, {'classprefix': 'p-', 'cssclass': 'c', 'style': 'monokai'}]:
    for arg in [None, '', 'div']:
        fields = {'formatter': 'html', 'options': opts}
        if arg is not None:
            fields['arg'] = arg
        record('styledefs', fields,
               lambda: get_formatter_by_name('html', **opts).get_style_defs(
                   *([] if arg is None else [arg])))
    record('styledefs', {'formatter': 'html', 'options': opts, 'args': ['a', '.b', '']},
           lambda: get_formatter_by_name('html', **opts).get_style_defs(['a', '.b', '']))
for opts in [{'commandprefix': 'XY'}, {'style': 'monokai', 'commandprefix': 'Q'}]:
    record('styledefs', {'formatter': 'latex', 'options': opts},
           lambda: get_formatter_by_name('latex', **opts).get_style_defs())

sys.stderr = real_stderr

# ---------------------------------------------------------------------------
# filters

FILTER_OPTIONS = {
    'codetagify': [{}, {'codetags': 'FOO BUG'}, {'codetags': ''}],
    'keywordcase': [{}, {'case': 'upper'}, {'case': 'capitalize'}],
    'highlight': [{'names': 'x y f'}, {'names': 'bar', 'tokentype': 'Keyword'}],
    'raiseonerror': [{}],
    'whitespace': [{}, {'spaces': T, 'tabs': T, 'newlines': T},
                   {'spaces': '_', 'tabs': '>', 'tabsize': '4', 'wstokentype': 'False'},
                   {'spaces': T, 'newlines': T, 'wstokentype': 'False'}],
    'gobble': [{}, {'n': '2'}, {'n': '5'}],
    'tokenmerge': [{}],
    'symbols': [{}, {'lang': 'latex'}],
}
tokens_sets['symbols'] = [
    (Token.Name, '\\<alpha>'), (Token.Text, ' '), (Token.Name, '\\alpha'),
    (Token.Text, ' '), (Token.Operator, '\\<longrightarrow>'), (Token.Text, '\n'),
]
tokens_sets['greek'] = [
    (Token.Keyword, 'ΟΔΟΣ'), (Token.Text, ' '), (Token.Keyword, 'ǆemal straße'),
    (Token.Keyword.Type, 'İstanbul'), (Token.Text, '\n'),
]
emit({'kind': 'tokens', 'key': 'symbols', 'tokens': ser(tokens_sets['symbols'])})
emit({'kind': 'tokens', 'key': 'greek', 'tokens': ser(tokens_sets['greek'])})
assert set(FILTER_OPTIONS) == set(get_all_filters())
for name, option_sets in FILTER_OPTIONS.items():
    for options in option_sets:
        for key in ['basic', 'custom', 'ex_c', 'symbols', 'greek', 'empty']:
            if key not in tokens_sets:
                continue
            record('filter', {'filter': name, 'options': options, 'tokens': key},
                   lambda: ser(get_filter_by_name(name, **options).filter(
                       None, iter(tokens_sets[key]))))

print(case_id, 'cases ->', OUT_PATH)
