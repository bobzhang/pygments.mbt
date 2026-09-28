"""Python counterpart of cmd/bench: best-of-N lex and format times."""
import sys, os, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '.repos', 'pygments'))
from pygments.lexers import get_lexer_by_name
from pygments.formatters import get_formatter_by_name
alias, path = sys.argv[1], sys.argv[2]
repeat = int(sys.argv[3]) if len(sys.argv) > 3 else 1
fmt = get_formatter_by_name(sys.argv[4] if len(sys.argv) > 4 else 'terminal256')
text = open(path, encoding='utf-8').read()
lx = get_lexer_by_name(alias)
bl = bf = 1e9
for _ in range(repeat):
    t0 = time.perf_counter(); toks = list(lx.get_tokens(text)); t1 = time.perf_counter()
    out = fmt.format(toks, open(os.devnull, 'w')); t2 = time.perf_counter()
    bl = min(bl, t1 - t0); bf = min(bf, t2 - t1)
print(f'tokens={len(toks)} lex_ms={bl*1000:.0f} format_ms={bf*1000:.0f}')
