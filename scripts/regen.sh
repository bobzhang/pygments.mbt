#!/bin/sh
# Regenerate every generated MoonBit file from the pinned Pygments checkout.
set -e
export PYTHONHASHSEED=0
cd "$(dirname "$0")/.."
scripts/fetch_pygments.sh
python3 scripts/gen_unicode_tables.py regex/unicode_tables.mbt
python3 scripts/gen_pystr_tables.py
python3 scripts/export_lexers.py
python3 scripts/export_styles.py
python3 scripts/export_filters.py
python3 scripts/export_cli_docs.py
moon fmt
