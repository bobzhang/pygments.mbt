"""Cross-feeding corpus: every lexer lexes a few *foreign* inputs.

Output has the same format as scripts/lexer_oracle.py (file, alias, input,
tokens), so cmd/lexer_oracle can replay it.
"""
import sys, os, json, random, glob
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PYG = os.path.join(ROOT, '.repos', 'pygments')
sys.path.insert(0, PYG)
from pygments.lexers import LEXERS, get_lexer_by_name

random.seed(int(os.environ.get('SEED', '7')))
PER = int(os.environ.get('PER', '3'))
MAXLEN = int(os.environ.get('MAXLEN', '1500'))
inputs = []
for path in sorted(glob.glob(os.path.join(PYG, 'tests', 'examplefiles', '*', '*'))):
    if path.endswith('.output'):
        continue
    try:
        inputs.append((os.path.relpath(path, PYG), open(path, encoding='utf-8').read()))
    except UnicodeDecodeError:
        pass
out = open(sys.argv[1], 'w')
n = 0
for name, (mod, lname, aliases, fns, mts) in sorted(LEXERS.items()):
    if not aliases:
        continue
    alias = aliases[0]
    for _ in range(PER):
        f, text = random.choice(inputs)
        start = random.randint(0, max(0, len(text) - MAXLEN))
        inp = text[start:start + MAXLEN]
        try:
            toks = [[str(t)[6:] if str(t) != 'Token' else '', v]
                    for t, v in get_lexer_by_name(alias).get_tokens(inp)]
        except Exception as e:
            continue
        out.write(json.dumps({'file': f'{alias}<-{f}@{start}', 'alias': alias,
                              'input': inp, 'tokens': toks}) + '\n')
        n += 1
print(n, 'cases')
