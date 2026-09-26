#!/bin/sh
# Differential tests against the pinned Python Pygments: regex engine, lexers,
# analyse_text/guess_lexer, formatters and the pygmentize CLI.
set -e
export PYTHONHASHSEED=0
cd "$(dirname "$0")/.."
scripts/fetch_pygments.sh
mkdir -p .oracle
python3 scripts/regex_oracle.py .oracle/regex.jsonl
python3 scripts/lexer_oracle.py .oracle/lexers.jsonl
python3 scripts/analyse_oracle.py .oracle/lexers.jsonl .oracle/analyse.jsonl
python3 scripts/cross_oracle.py .oracle/cross.jsonl
python3 scripts/formatter_oracle.py .oracle/formatters.jsonl
moon build --target native --release
B=_build/native/release/build/cmd
$B/regex_oracle/regex_oracle.exe .oracle/regex.jsonl
$B/lexer_oracle/lexer_oracle.exe .oracle/lexers.jsonl --quiet
$B/lexer_oracle/lexer_oracle.exe .oracle/cross.jsonl --quiet
$B/lexer_oracle/lexer_oracle.exe --analyse .oracle/analyse.jsonl --quiet
$B/formatter_oracle/formatter_oracle.exe .oracle/formatters.jsonl --quiet
python3 scripts/cli_compare.py $B/pygmentize/pygmentize.exe
