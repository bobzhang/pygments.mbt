#!/bin/sh
# Builds the inputs used for the README performance table in .bench/:
# python.py (all upstream lexer modules, 4.1 MB), c.c (C example files x10,
# 1.1 MB) and html.html (HTML example files x40, 1.4 MB).
set -e
cd "$(dirname "$0")/.."
scripts/fetch_pygments.sh
P=.repos/pygments
mkdir -p .bench
cat $P/pygments/lexers/*.py > .bench/python.py
C=$(find $P/tests/examplefiles \( -name '*.c' -o -name '*.h' \) | sort)
H=$(find $P/tests/examplefiles \( -name '*.html' -o -name '*.htm' \) | sort)
: > .bench/c.c
: > .bench/html.html
for i in 1 2 3 4 5 6 7 8 9 10; do cat $C >> .bench/c.c; done
for i in $(seq 40); do cat $H >> .bench/html.html; done
wc -c .bench/*
