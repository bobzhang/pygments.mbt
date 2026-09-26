"""Export pygments lexers to MoonBit (package `lexers/`).

Imports every lexer of the pinned upstream checkout, lets the RegexLexer
metaclass resolve include/inherit/words/default/combined, and writes:

  lexers/gen_tokens.mbt      token type constants used by generated tables
  lexers/gen_patterns.mbt    the global pool of regex patterns
  lexers/gen_<module>.mbt    lexer metadata, RegexDefs and constructors
  lexers/gen_registry.mbt    the table of all lexers
  lexers/MANIFEST.md         what still needs hand-written MoonBit

Hand-written parts live in lexers/*.mbt files not starting with `gen_` and are
discovered by name:

  fn <snake>_tokenizer(...)   full tokenizer (overrides / non-regex lexers)
  fn <snake>_callbacks(...)   bespoke callbacks of a regex lexer
  fn <snake>_analyse(...)     analyse_text

Unknown callables in token definitions abort the export.
"""
import sys, os, re, importlib, glob, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, '.repos', 'pygments'))
sys.path.insert(0, HERE)
from pyre_util import escape_surrogates
from pygments.lexers import LEXERS
from pygments.lexer import (RegexLexer, ExtendedRegexLexer, DelegatingLexer,
                            Lexer, _TokenType, this)
from pygments.token import Other

OUT = os.path.join(ROOT, 'lexers')


def snake(name):
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name)
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', s)
    return s.lower()


def mbt_str(s):
    s = escape_surrogates(s)
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ch == '\n':
            out.append('\\n')
        elif ch == '\r':
            out.append('\\r')
        elif ch == '\t':
            out.append('\\t')
        elif o < 0x20 or o == 0x7f or 0x80 <= o < 0xa0 or o in (0x2028, 0x2029, 0xfeff) \
                or 0xfff0 <= o <= 0xffff or (0xe000 <= o <= 0xf8ff):
            out.append('\\u{%x}' % o)
        else:
            out.append(ch)
    out.append('"')
    return ''.join(out)


# ---------------------------------------------------------------- hand-written
handwritten = {}
for f in glob.glob(os.path.join(OUT, '*.mbt')):
    if os.path.basename(f).startswith('gen_'):
        continue
    for m in re.finditer(r'^(?:pub )?fn ([a-z0-9_]+)', open(f).read(), re.M):
        handwritten[m.group(1)] = os.path.basename(f)


def have(fn):
    return fn in handwritten


# ---------------------------------------------------------------- tokens
token_names = {}


def tok(t):
    path = '.'.join(t)
    if path not in token_names:
        base = 'tk_' + ('_'.join(p.lower() for p in t) if t else 'token')
        name = base
        i = 2
        while name in token_names.values():
            name = f'{base}_{i}'
            i += 1
        token_names[path] = name
    return token_names[path]


# ---------------------------------------------------------------- patterns
pattern_ids = {}


def pat(p):
    p = escape_surrogates(p)
    if p not in pattern_ids:
        pattern_ids[p] = len(pattern_ids)
    return pattern_ids[p]


class ExportError(Exception):
    pass


def closure_vars(fn):
    if not fn.__closure__:
        return {}
    return dict(zip(fn.__code__.co_freevars, (c.cell_contents for c in fn.__closure__)))


def callback_arg(v):
    if isinstance(v, bool):
        return f'Bool({"true" if v else "false"})'
    if isinstance(v, int):
        return f'Int({v})'
    if isinstance(v, str):
        return f'Str({mbt_str(v)})'
    if type(v) is _TokenType:
        return f'Tok({tok(v)})'
    raise ExportError(f'unsupported callback argument {v!r}')


def opt_value(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (list, tuple)):
        return ' '.join(map(str, v))
    return str(v)


def action(a, ctx):
    """MoonBit expression for a token action."""
    if a is None:
        return 'Nop'
    if type(a) is _TokenType:
        return f'Emit({tok(a)})'
    qn = getattr(a, '__qualname__', '')
    cv = closure_vars(a)
    if qn == 'bygroups.<locals>.callback':
        return 'ByGroups([' + ', '.join(action(x, ctx) for x in cv['args']) + '])'
    if qn == 'using.<locals>.callback':
        kwargs = cv.get('kwargs', {})
        gt = cv.get('gt_kwargs', {})
        stack = gt.get('stack')
        other = cv.get('_other')
        if other is None or other is this:
            target = 'This'
        else:
            ctx['using'].add(other.__name__)
            reference(other)
            target = f'Other(opts => {snake(other.__name__)}(options=opts))'
        stack_s = 'None' if stack is None else 'Some([' + ', '.join(mbt_str(s) for s in stack) + '])'
        kw = '[' + ', '.join(f'({mbt_str(k)}, {mbt_str(opt_value(v))})' for k, v in sorted(kwargs.items())) + ']'
        return f'Using({target}, {stack_s}, {kw})'
    if callable(a):
        name = qn.replace('.<locals>.callback', '').replace('.<locals>.', '.')
        args = []
        for k in sorted(cv):
            v = cv[k]
            if callable(v) and not type(v) is _TokenType:
                raise ExportError(f'callback {qn} captures callable {k}')
            args.append(callback_arg(v))
        ctx['callbacks'].add(name)
        return f'Call({mbt_str(name)}, [{", ".join(args)}])'
    raise ExportError(f'unknown action {a!r}')


def transition(ns):
    if ns is None:
        return 'None'
    if isinstance(ns, int):
        return 'Some([' + ', '.join(['Pop'] * (-ns)) + '])'
    if ns == '#push':
        return 'Some([Dup])'
    if isinstance(ns, tuple):
        ops = []
        for s in ns:
            if s == '#pop':
                ops.append('Pop')
            elif s == '#push':
                ops.append('Dup')
            else:
                ops.append(f'Push({mbt_str(s)})')
        return 'Some([' + ', '.join(ops) + '])'
    raise ExportError(f'unknown transition {ns!r}')


def regex_def(cls, tokens, defname, ctx):
    """MoonBit code for a RegexDef value from processed tokens."""
    rule_ids = {}
    rules = []
    states = []
    names = list(tokens.keys())
    if 'root' not in names:
        raise ExportError(f'{cls.__name__}: no root state')
    for st in names:
        idxs = []
        for r in tokens[st]:
            if id(r) not in rule_ids:
                rex, act, ns = r
                p = rex.__self__.pattern
                flags = int(rex.__self__.flags & ~re.UNICODE)
                rule_ids[id(r)] = len(rules)
                rules.append(f'r({pat(p)}, {flags}, {action(act, ctx)}, {transition(ns)})')
            idxs.append(str(rule_ids[id(r)]))
        states.append('[' + ', '.join(idxs) + ']')
    ext = 'true' if issubclass(cls, ExtendedRegexLexer) else 'false'
    lines = [f'///|\nlet {defname} : @lazy.Lazy[@lexer.RegexDef] = @lazy.Lazy(() => {{']
    lines.append(f'  let rules = [')
    for r in rules:
        lines.append(f'    {r},')
    lines.append('  ]')
    lines.append('  @lexer.RegexDef::new(')
    lines.append(f'    {mbt_str(cls.__name__)},')
    lines.append('    [' + ', '.join(mbt_str(n) for n in names) + '],')
    lines.append('    rules,')
    lines.append('    [' + ', '.join(states) + '],')
    lines.append(f'    extended={ext},')
    lines.append('  )')
    lines.append('})\n')
    return '\n'.join(lines)


def overrides(cls):
    """Classes between cls and RegexLexer/Lexer defining tokenizer-relevant methods."""
    found = []
    for c in cls.__mro__:
        if c in (RegexLexer, ExtendedRegexLexer, DelegatingLexer, Lexer):
            break
        for m in ('get_tokens_unprocessed', '__init__'):
            if m in c.__dict__:
                found.append(f'{c.__name__}.{m}')
    return found


def defines_analyse(cls):
    for c in cls.__mro__:
        if c in (RegexLexer, ExtendedRegexLexer, DelegatingLexer, Lexer):
            return None
        if 'analyse_text' in c.__dict__:
            return c.__name__
    return None


# option selecting the token variant of `token_variants` lexers
VARIANT_OPTION = {
    'CSharpLexer': 'unicodelevel',
    'NemerleLexer': 'unicodelevel',
    'Inform7Lexer': 'i6t',
    'Inform6TemplateLexer': 'i6t',
}

# ---------------------------------------------------------------- main loop
modules = collections.defaultdict(list)
manifest = []
registry = []
queue = [(name, modname, lname, aliases, filenames, mimetypes, True)
         for name, (modname, lname, aliases, filenames, mimetypes) in sorted(LEXERS.items())]
known = {q[0] for q in queue}
helper_classes = {}


def reference(c):
    """Record a lexer class referenced by using()/DelegatingLexer."""
    if c.__name__ not in known:
        known.add(c.__name__)
        helper_classes[c.__name__] = c
        queue.append((c.__name__, c.__module__, c.name or c.__name__, list(c.aliases),
                      list(c.filenames), list(c.mimetypes), False))


qi = 0
while qi < len(queue):
    name, modname, lname, aliases, filenames, mimetypes, public = queue[qi]
    qi += 1
    mod = importlib.import_module(modname)
    cls = helper_classes.get(name) or getattr(mod, name)
    sn = snake(name)
    ctx = {'callbacks': set(), 'using': set()}
    code = []
    kind = None
    todo = []
    ov = overrides(cls)
    if issubclass(cls, RegexLexer) and not getattr(cls, 'token_variants', False):
        kind = 'extended' if issubclass(cls, ExtendedRegexLexer) else 'regex'
        cls()
        code.append(regex_def(cls, cls._tokens, f'{sn}_def', ctx))
        cb = f'{sn}_callbacks'
        tz = f'{sn}_tokenizer'
        if have(tz):
            tokenizer = tz
        else:
            if ov:
                todo.append('tokenizer (' + ', '.join(ov) + ')')
            if ctx['callbacks']:
                if have(cb):
                    tokenizer = f'(lx, text, stack) => @lexer.run_regex(lx, {sn}_def.force(), text, stack, callbacks={cb}(lx))'
                else:
                    todo.append('callbacks ' + ', '.join(sorted(ctx['callbacks'])))
                    tokenizer = f'(lx, text, stack) => @lexer.run_regex(lx, {sn}_def.force(), text, stack)'
            else:
                tokenizer = f'(lx, text, stack) => @lexer.run_regex(lx, {sn}_def.force(), text, stack)'
    elif issubclass(cls, RegexLexer):
        kind = 'variants'
        opt = VARIANT_OPTION[name]
        levels = list(cls.tokens.keys()) if isinstance(cls.token_variants, bool) else list(cls.token_variants)
        entries = []
        for lv in levels:
            processed = cls(**{opt: lv})._tokens
            dn = f'{sn}_def_{re.sub(r"[^a-z0-9]", "_", lv.lower())}'
            code.append(regex_def(cls, processed, dn, ctx))
            entries.append((lv, dn))
        code.append(f'///|\nlet {sn}_variants : Array[(String, @lazy.Lazy[@lexer.RegexDef])] = [' +
                    ', '.join(f'({mbt_str(lv)}, {dn})' for lv, dn in entries) + ']\n')
        tz = f'{sn}_tokenizer'
        if have(tz):
            tokenizer = tz
        else:
            todo.append('tokenizer (token_variants)')
            tokenizer = (f'(lx, text, stack) => @lexer.run_regex(lx, {sn}_variants[0].1.force(), text, stack'
                         + (f', callbacks={sn}_callbacks(lx)' if ctx['callbacks'] and have(f'{sn}_callbacks') else '') + ')')
        if ctx['callbacks'] and not have(f'{sn}_callbacks'):
            todo.append('callbacks ' + ', '.join(sorted(ctx['callbacks'])))
    elif issubclass(cls, DelegatingLexer):
        kind = 'delegating'
        inst = cls()
        root = type(inst.root_lexer).__name__
        lang = type(inst.language_lexer).__name__
        reference(type(inst.root_lexer))
        reference(type(inst.language_lexer))
        needle = inst.needle
        tz = f'{sn}_tokenizer'
        if have(tz):
            tokenizer = tz
        else:
            gtu = [c.__name__ for c in cls.__mro__[:cls.__mro__.index(DelegatingLexer)]
                   if 'get_tokens_unprocessed' in c.__dict__]
            if gtu:
                todo.append('tokenizer (' + ', '.join(gtu) + ')')
            tokenizer = (f'(lx, text, _) => @lexer.delegate({snake(root)}(options=lx.options), '
                         f'{snake(lang)}(options=lx.options), text, needle={tok(needle)})')
    else:
        kind = 'custom'
        tz = f'{sn}_tokenizer'
        if have(tz):
            tokenizer = tz
        else:
            todo.append('tokenizer (non-regex lexer)')
            tokenizer = '(lx, text, stack) => @lexer.text_tokenizer(lx, text, stack)'
    an = defines_analyse(cls)
    analyse = f'{sn}_analyse' if have(f'{sn}_analyse') else '@lexer.no_analyse'
    if an and not have(f'{sn}_analyse'):
        todo.append(f'analyse_text ({an})')
    info = (f'///|\n{"pub " if public else ""}let {sn}_info : @lexer.LexerInfo = {{\n'
            f'  class_name: {mbt_str(name)},\n'
            f'  name: {mbt_str(lname)},\n'
            f'  aliases: [{", ".join(mbt_str(a) for a in aliases)}],\n'
            f'  filenames: [{", ".join(mbt_str(a) for a in filenames)}],\n'
            f'  alias_filenames: [{", ".join(mbt_str(a) for a in cls.alias_filenames)}],\n'
            f'  mimetypes: [{", ".join(mbt_str(a) for a in mimetypes)}],\n'
            f'  priority: {float(cls.priority)!r},\n'
            f'  url: {mbt_str(cls.url or "")},\n'
            f'  version_added: {mbt_str(cls.version_added or "")},\n'
            f'  analyse_text: {analyse},\n'
            f'}}\n')
    ctor = (f'///|\n/// Creates a `{name}` ({lname}).\n'
            f'{"pub " if public else ""}fn {sn}(options? : @lexer.Options = Map([])) -> @lexer.Lexer raise {{\n'
            f'  @lexer.Lexer::new({sn}_info, options, opts => {sn}(options=opts), {tokenizer})\n'
            f'}}\n')
    modules[modname.split('.')[-1]].append('\n'.join([info] + code + [ctor]))
    if public:
        registry.append((name, sn))
    manifest.append((name + ('' if public else ' (helper)'), modname, kind, todo))

os.makedirs(OUT, exist_ok=True)
for f in glob.glob(os.path.join(OUT, 'gen_*.mbt')):
    os.remove(f)
HEADER = '// Generated by scripts/export_lexers.py from pygments. DO NOT EDIT.\n\n'
for m, parts in sorted(modules.items()):
    with open(os.path.join(OUT, f'gen_{m.lstrip("_")}.mbt'), 'w') as fh:
        fh.write(HEADER + '\n'.join(parts))

with open(os.path.join(OUT, 'gen_tokens.mbt'), 'w') as fh:
    fh.write(HEADER)
    for path, nm in sorted(token_names.items(), key=lambda kv: kv[1]):
        fh.write(f'///|\nlet {nm} : @token.TokenType = @token.from_string({mbt_str(path)})\n\n')

with open(os.path.join(OUT, 'gen_patterns.mbt'), 'w') as fh:
    fh.write(HEADER)
    fh.write('///|\nlet pattern_pool : FixedArray[String] = [\n')
    for p, i in sorted(pattern_ids.items(), key=lambda kv: kv[1]):
        fh.write(f'  {mbt_str(p)},\n')
    fh.write(']\n')

with open(os.path.join(OUT, 'gen_registry.mbt'), 'w') as fh:
    fh.write(HEADER)
    fh.write('///|\n/// Every builtin lexer class: metadata and constructor.\n'
             'pub let all_lexers : Array[(@lexer.LexerInfo, (@lexer.Options) -> @lexer.Lexer raise)] = [\n')
    for name, sn in registry:
        fh.write(f'  ({sn}_info, opts => {sn}(options=opts)),\n')
    fh.write(']\n')

# ---------------------------------------------------------------- python data
# `// pydata: <name> = <expr>` lines in hand-written lexers/*.mbt files
DATA = {}
for f in sorted(glob.glob(os.path.join(OUT, '*.mbt'))):
    if os.path.basename(f).startswith('gen_'):
        continue
    for m in re.finditer(r'^// pydata: ([a-z0-9_]+) = (.+)$', open(f).read(), re.M):
        if m.group(1) in DATA:
            raise ExportError(f'duplicate pydata {m.group(1)}')
        DATA[m.group(1)] = m.group(2).strip()


class _Loader:
    def __getattr__(self, name):
        return importlib.import_module('pygments.lexers.' + name)


def wrap_list(items):
    """An array literal with one element per line."""
    items = list(items)
    if not items:
        return '[]'
    return '[\n' + ''.join(f'  {x},\n' for x in items) + ']'


def data_value(v):
    if isinstance(v, bool):
        return 'Bool', 'true' if v else 'false'
    if isinstance(v, int):
        return 'Int', str(v)
    if isinstance(v, str):
        return 'String', mbt_str(v)
    if isinstance(v, (set, frozenset)):
        return '@set.Set[String]', '@set.Set(' + wrap_list(mbt_str(x) for x in sorted(v)) + ')'
    if isinstance(v, (list, tuple)):
        return 'Array[String]', wrap_list(mbt_str(x) for x in v)
    if isinstance(v, dict):
        if all(isinstance(x, str) for x in v.values()):
            return 'Map[String, String]', 'Map::from_array([' + ', '.join(
                f'({mbt_str(k)}, {mbt_str(x)})' for k, x in v.items()) + '])'
        return 'Map[String, Array[String]]', 'Map::from_array([' + ', '.join(
            f'({mbt_str(k)}, [' + ', '.join(mbt_str(y) for y in x) + '])' for k, x in v.items()) + '])'
    raise ExportError(f'unsupported data value {v!r}')


with open(os.path.join(OUT, 'gen_pydata.mbt'), 'w') as fh:
    fh.write(HEADER)
    for name, expr in DATA.items():
        ty, val = data_value(eval(expr, {'L': _Loader()}))
        fh.write(f'///|\n/// `{expr[2:]}`\nlet {name} : {ty} = {val}\n\n')

done = sum(1 for m in manifest if not m[3])
with open(os.path.join(OUT, 'MANIFEST.md'), 'w') as fh:
    fh.write('# Lexer port manifest\n\nGenerated by `scripts/export_lexers.py`.\n\n')
    fh.write(f'{len(manifest)} lexers, {done} complete, {len(manifest) - done} with hand-written parts missing.\n\n')
    fh.write('| Lexer | MoonBit prefix | Module | Kind | Missing |\n|---|---|---|---|---|\n')
    for name, modname, kind, todo in manifest:
        fh.write(f'| {name} | `{snake(name.split()[0])}` | {modname.split(".")[-1]} | {kind} | {"; ".join(todo)} |\n')
print(len(manifest), 'lexers,', done, 'complete;', len(pattern_ids), 'patterns;', len(token_names), 'tokens')
