"""Build a differential-test corpus for the MoonBit regex engine.

For every (pattern, flags) used by a pygments RegexLexer, record Python's
`pattern.match(text, pos)` result (all group spans, as UTF-16 offsets) at
positions where the pattern matches plus random positions, over example
text for that lexer and a synthetic Unicode text.

Output: JSON lines. Line 1: {"texts": [...]}; then one line per pattern:
{"p": pattern, "f": flags, "c": [[text_id, pos16, spans16 | null], ...]}
"""
import sys, os, re, json, random, importlib, glob
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.repos', 'pygments'))
from pygments.lexers import LEXERS
from pygments.lexer import RegexLexer
sys.path.insert(0, os.path.dirname(__file__))
from pyre_util import escape_surrogates

ROOT = os.path.join(os.path.dirname(__file__), '..', '.repos', 'pygments', 'tests')
random.seed(1234)
MAXLEN = int(os.environ.get('ORACLE_MAXLEN', '3000'))
POSITIVE = int(os.environ.get('ORACLE_POS', '6'))
RANDOM = int(os.environ.get('ORACLE_RAND', '6'))

SYNTH = ("héllo wörld ÀÉÎ ſ K ǅ ß ﬀ İ ı Σσς 😀 𝒜𝓑 x=1; y = \"str\\n\" # c\n"
         "  if (a && b) { return 0x1F; }\n\t// Ünïcödé 中文 ２３ \U0001F600end\n")


def example_text(aliases):
    for a in aliases:
        d = os.path.join(ROOT, 'examplefiles', a)
        if os.path.isdir(d):
            for f in sorted(os.listdir(d)):
                if f.endswith('.output'):
                    continue
                try:
                    return open(os.path.join(d, f), encoding='utf-8').read()[:MAXLEN]
                except Exception:
                    pass
    return None


def utf16_offsets(s):
    offs = [0] * (len(s) + 1)
    o = 0
    for i, ch in enumerate(s):
        offs[i] = o
        o += 2 if ord(ch) > 0xFFFF else 1
    offs[len(s)] = o
    return offs


texts = [SYNTH]
text_ids = {SYNTH: 0}
offsets = [utf16_offsets(SYNTH)]
seen = {}
order = []
for name, (mod, lname, aliases, fn, mt) in sorted(LEXERS.items()):
    cls = getattr(importlib.import_module(mod), name)
    if not issubclass(cls, RegexLexer) or getattr(cls, 'token_variants', False):
        continue
    try:
        cls()
    except Exception:
        continue
    txt = example_text(aliases)
    if txt is not None and txt not in text_ids:
        text_ids[txt] = len(texts)
        texts.append(txt)
        offsets.append(utf16_offsets(txt))
    tid = text_ids.get(txt, 0) if txt is not None else 0
    for st, rules in cls._tokens.items():
        for rex, _, _ in rules:
            key = (rex.__self__.pattern, rex.__self__.flags)
            if key not in seen:
                seen[key] = set()
                order.append(key)
            seen[key].add(tid)


def cases_for(rx, tid):
    text = texts[tid]
    offs = offsets[tid]
    positions = set()
    p = 0
    for _ in range(POSITIVE):
        if p > len(text):
            break
        m = rx.search(text, p)
        if not m:
            break
        positions.add(m.start())
        p = m.start() + 1
    for _ in range(RANDOM):
        positions.add(random.randint(0, len(text)))
    out = []
    for pos in sorted(positions):
        m = rx.match(text, pos)
        if m is None:
            out.append([tid, offs[pos], None])
        else:
            spans = []
            for g in range(rx.groups + 1):
                s, e = m.span(g)
                spans += [offs[s], offs[e]] if s >= 0 else [-1, -1]
            out.append([tid, offs[pos], spans])
    return out


import signal


class Slow(Exception):
    pass


def on_alarm(*_):
    raise Slow()


signal.signal(signal.SIGALRM, on_alarm)
out = open(sys.argv[1], 'w')
out.write(json.dumps({"texts": texts}) + "\n")
slow = 0
for key in order:
    pat, flags = key
    rx = re.compile(pat, flags)
    cases = []
    for tid in sorted(seen[key] | {0}):
        signal.alarm(2)
        try:
            cases += cases_for(rx, tid)
        except Slow:
            slow += 1
            print("slow pattern skipped:", repr(pat)[:120], file=sys.stderr)
        finally:
            signal.alarm(0)
    out.write(json.dumps({"p": escape_surrogates(pat), "f": flags & ~re.UNICODE, "c": cases}) + "\n")
print(len(order), "patterns", len(texts), "texts", slow, "slow")
