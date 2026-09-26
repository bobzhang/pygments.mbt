"""Python constants exported to lexers/gen_pydata.mbt for hand-written code.

Each entry maps a MoonBit identifier to a Python expression evaluated with
`L` bound to a lazy loader of `pygments.lexers.<module>` (e.g.
`L.c_cpp.CFamilyLexer.stdlib_types`). Supported values:

  list/tuple of str      -> Array[String]
  set/frozenset of str   -> @set.Set[String]   (sorted)
  dict str -> str        -> Map[String, String]
  dict str -> list[str]  -> Map[String, Array[String]]
  str / int / bool       -> String / Int / Bool
"""

DATA = {
    'c_stdlib_types': 'L.c_cpp.CFamilyLexer.stdlib_types',
    'c_c99_types': 'L.c_cpp.CFamilyLexer.c99_types',
    'c_linux_types': 'L.c_cpp.CFamilyLexer.linux_types',
    'c_c11_atomic_types': 'L.c_cpp.CFamilyLexer.c11_atomic_types',
}
