"""Helpers shared by the export scripts."""


def escape_surrogates(pat):
    """Rewrite lone surrogate code points in a regex pattern as `\\uXXXX`
    escapes (they cannot be stored in JSON or MoonBit string literals).
    An escaped surrogate (backslash + surrogate) means the same character."""
    out = []
    i = 0
    n = len(pat)
    while i < n:
        c = pat[i]
        if c == '\\' and i + 1 < n:
            d = pat[i + 1]
            if 0xD800 <= ord(d) <= 0xDFFF:
                out.append('\\u%04x' % ord(d))
            else:
                out.append(c + d)
            i += 2
            continue
        if 0xD800 <= ord(c) <= 0xDFFF:
            out.append('\\u%04x' % ord(c))
        else:
            out.append(c)
        i += 1
    return ''.join(out)
