"""Build the lexer conformance corpus from pygments' own test inputs.

For each file under tests/snippets and tests/examplefiles, record the lexer
alias (the directory name), the input, and Python's `get_tokens` output.
Output: JSON lines {"file", "alias", "input", "tokens": [[ttype, value], ...]}.
"""
import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PYG = os.path.join(ROOT, '.repos', 'pygments')
sys.path.insert(0, PYG)
from pygments.lexers import get_lexer_by_name

out = open(sys.argv[1], 'w')
n = 0
for path in sorted(glob.glob(os.path.join(PYG, 'tests', 'snippets', '*', '*.txt'))):
    content = open(path, encoding='utf-8').read()
    content, _, _ = content.partition('\n---tokens---\n')
    if content.startswith('---input---\n'):
        content = '\n' + content
    _, _, inp = content.rpartition('\n---input---\n')
    if not inp.endswith('\n'):
        inp += '\n'
    alias = os.path.basename(os.path.dirname(path))
    toks = [[str(t)[6:] if str(t) != 'Token' else '', v]
            for t, v in get_lexer_by_name(alias).get_tokens(inp)]
    out.write(json.dumps({'file': os.path.relpath(path, PYG), 'alias': alias,
                          'input': inp, 'tokens': toks}) + '\n')
    n += 1
for path in sorted(glob.glob(os.path.join(PYG, 'tests', 'examplefiles', '*', '*'))):
    if path.endswith('.output'):
        continue
    try:
        inp = open(path, encoding='utf-8').read()
    except UnicodeDecodeError:
        continue
    alias = os.path.basename(os.path.dirname(path))
    toks = [[str(t)[6:] if str(t) != 'Token' else '', v]
            for t, v in get_lexer_by_name(alias).get_tokens(inp)]
    out.write(json.dumps({'file': os.path.relpath(path, PYG), 'alias': alias,
                          'input': inp, 'tokens': toks}) + '\n')
    n += 1
print(n, 'cases')
