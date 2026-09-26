"""Compare `pygmentize` (MoonBit build) with Python's on a set of invocations.

Usage: python3 scripts/cli_compare.py path/to/pygmentize.exe
"""
import sys, os, subprocess, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PYG = os.path.join(ROOT, '.repos', 'pygments')
EX = os.path.join(PYG, 'tests', 'examplefiles')
exe = os.path.abspath(sys.argv[1])
py = [sys.executable, '-c', 'import sys; sys.path.insert(0, %r); from pygments.cmdline import main; sys.exit(main(sys.argv))' % PYG]

files = [f'{EX}/python/switch_case.py', f'{EX}/c/example.c', f'{EX}/html/test.html',
         f'{EX}/rb/test.rb', f'{EX}/yaml/example.yaml', f'{EX}/md/example.md']
cases = []
for f in files:
    for fmt in ['html', 'terminal', 'terminal256', 'terminal16m', 'latex', 'rtf', 'svg',
                'bbcode', 'irc', 'groff', 'pango', 'raw', 'testcase', 'text']:
        cases.append(['-f', fmt, f])
    cases.append(['-f', 'html', '-O', 'full,linenos=table,style=monokai,title=T', f])
    cases.append(['-f', 'html', '-O', 'noclasses,hl_lines=1 3', '-F', 'whitespace:spaces=True', f])
    cases.append(['-g', '-f', 'html', f])
cases += [
    ['-L', 'lexers'], ['-L', 'formatters', 'styles'], ['-L', 'filters'], ['-L', '--json'],
    ['-L', 'styles', '--json'],
    ['-N', 'foo.rs'], ['-N', 'unknown.zzz'], ['-N', 'Makefile'],
    ['-S', 'default', '-f', 'html'], ['-S', 'monokai', '-f', 'html', '-a', '.hl'],
    ['-S', 'friendly', '-f', 'latex'], ['-S', 'emacs', '-f', 'terminal'],
    ['-H', 'lexer', 'python'], ['-H', 'formatter', 'html'], ['-H', 'filter', 'keywordcase'],
    ['-H', 'lexer', 'nonexistent'],
    ['-l', 'nonexistent', f'{EX}/c/example.c'], ['-f', 'nonexistent', f'{EX}/c/example.c'],
    ['-l', 'python', '-F', 'keywordcase:case=upper', '-f', 'text', f'{EX}/python/switch_case.py'],
    ['-l', 'c', '-f', 'latex', '-O', 'escapeinside=||', f'{EX}/c/example.c'],
    ['-a', 'x'], ['-l', 'python', '-g'], ['-V'],
]
stdin_cases = [(['-C'], f'{EX}/python/switch_case.py'), (['-l', 'python', '-f', 'html'], f'{EX}/python/switch_case.py'),
               (['-f', 'html'], f'{EX}/c/example.c'), (['-s', '-l', 'sql', '-f', 'html'], f'{EX}/c/example.c')]

ok = bad = 0
def run(cmd, stdin=None, cwd=None):
    r = subprocess.run(cmd, input=stdin, capture_output=True, cwd=cwd, env={**os.environ, 'TERM': 'xterm', 'COLORTERM': ''})
    return r.returncode, r.stdout, r.stderr

def compare(args, stdin=None):
    global ok, bad
    a = run(py + args, stdin)
    b = run([exe] + args, stdin)
    # -V/-L headers mention the Python implementation identically; stderr for usage differs in wording
    same = a[0] == b[0] and a[1] == b[1]
    if same:
        ok += 1
    else:
        bad += 1
        print('DIFF', ' '.join(os.path.relpath(x, EX) if x.startswith(EX) else x for x in args),
              f'rc py={a[0]} mbt={b[0]}', f'stdout {len(a[1])} vs {len(b[1])} bytes')
        if a[1] != b[1]:
            for i, (x, y) in enumerate(zip(a[1], b[1])):
                if x != y:
                    print('   first difference at byte', i, repr(a[1][max(0, i-40):i+40]), '\n   vs', repr(b[1][max(0, i-40):i+40]))
                    break

for c in cases:
    compare(c)
for c, f in stdin_cases:
    compare(c, open(f, 'rb').read())
# output files (-o) including the html cssfile side file
tmp = tempfile.mkdtemp()
for impl, cmd in [('py', py), ('mbt', [exe])]:
    os.makedirs(f'{tmp}/{impl}')
    run(cmd + ['-O', 'full,cssfile=x.css', '-o', f'{tmp}/{impl}/out.html', f'{EX}/c/example.c'])
    run(cmd + ['-o', f'{tmp}/{impl}/out.tex', f'{EX}/c/example.c'])
for name in ['out.html', 'x.css', 'out.tex']:
    same = open(f'{tmp}/py/{name}', 'rb').read() == open(f'{tmp}/mbt/{name}', 'rb').read()
    ok += same; bad += not same
    if not same: print('DIFF output file', name)
shutil.rmtree(tmp)
print(f'cli: ok={ok} diff={bad}')
sys.exit(1 if bad else 0)
