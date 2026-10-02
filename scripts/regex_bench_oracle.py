"""Check `regex_bench --dump` (find_all and a match_at tokenizer loop over the
benchmark inputs) against CPython's `re`.

Usage: regex_bench --dump | python3 scripts/regex_bench_oracle.py
"""
import sys, re, json


def utf16_offsets(s):
    offs = [0] * (len(s) + 1)
    o = 0
    for i, ch in enumerate(s):
        offs[i] = o
        o += 2 if ord(ch) > 0xFFFF else 1
    offs[len(s)] = o
    return offs


def spans(m, offs):
    out = []
    for g in range(m.re.groups + 1):
        s, e = m.span(g)
        out += [offs[s] if s >= 0 else -1, offs[e] if e >= 0 else -1]
    return out


bad = 0
for line in sys.stdin:
    case = json.loads(line)
    got = case['spans']
    if case['kind'] == 'find_all':
        res = [re.compile(p) for p in case['patterns']]
        want = []
        for t in case['texts']:
            offs = utf16_offsets(t)
            for r in res:
                flat = []
                for m in r.finditer(t):
                    flat += spans(m, offs)
                want.append(flat)
    else:
        res = [re.compile(p, f) for p, f in case['patterns']]
        t = case['texts'][0]
        offs = utf16_offsets(t)
        want = []
        pos = 0
        while pos < len(t):
            nxt = pos + 1
            for i, r in enumerate(res):
                m = r.match(t, pos)
                if m:
                    if m.end() > pos:
                        nxt = m.end()
                    want.append([offs[pos], i] + spans(m, offs))
                    break
            pos = nxt
    n = len(want)
    diff = [i for i in range(max(n, len(got))) if i >= n or i >= len(got) or want[i] != got[i]]
    print(f"{case['name']}: {n} results, {len(diff)} mismatches")
    for i in diff[:5]:
        print('  want', want[i] if i < n else None)
        print('  got ', got[i] if i < len(got) else None)
    bad += len(diff)
sys.exit(1 if bad else 0)
