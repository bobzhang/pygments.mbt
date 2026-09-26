"""Record Python's analyse_text scores and guess_lexer results.

Uses the inputs of .oracle/lexers.jsonl. Output JSON lines:
{"file", "scores": {ClassName: score (non-zero only)}, "guess": ClassName | null}
"""
import sys, os, json, importlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, '.repos', 'pygments'))
from pygments.lexers import LEXERS, guess_lexer
from pygments.util import ClassNotFound

classes = []
for name, (mod, *_) in sorted(LEXERS.items()):
    classes.append((name, getattr(importlib.import_module(mod), name)))

out = open(sys.argv[2], 'w')
for line in open(sys.argv[1]):
    case = json.loads(line)
    text = case['input']
    scores = {}
    for name, cls in classes:
        s = cls.analyse_text(text)
        if s:
            scores[name] = s
    try:
        g = type(guess_lexer(text)).__name__
    except ClassNotFound:
        g = None
    out.write(json.dumps({'file': case['file'], 'input': text, 'scores': scores, 'guess': g}) + '\n')
