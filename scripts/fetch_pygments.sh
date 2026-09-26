#!/bin/sh
# Fetch the pinned upstream Pygments checkout into .repos/pygments.
set -e
cd "$(dirname "$0")/.."
COMMIT=$(cat scripts/PYGMENTS_COMMIT)
if [ -d .repos/pygments/.git ] && [ "$(git -C .repos/pygments rev-parse HEAD)" = "$COMMIT" ]; then
  exit 0
fi
rm -rf .repos/pygments
mkdir -p .repos/pygments
git -C .repos/pygments init -q
git -C .repos/pygments remote add origin https://github.com/pygments/pygments
git -C .repos/pygments fetch -q --depth 1 origin "$COMMIT"
git -C .repos/pygments checkout -q FETCH_HEAD
