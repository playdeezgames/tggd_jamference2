#!/usr/bin/env bash
# Builds the GitHub Pages site: tests, a size-optimised web build, copied into docs/. Never commits, never pushes.
# Usage: tools/pages.sh   (then commit docs/ and, when told to, git push)
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN=${ODIN:-odin}

"$ODIN" test src -define:ODIN_TEST_THREADS=1
rm -f odin # the test run leaves a stray binary named odin
ODIN="$ODIN" OPT=size ./build.sh
rm -rf docs
mkdir docs
cp -r build/web/. docs/
touch docs/.nojekyll
echo "docs/ ready ($(du -sh docs | cut -f1)). Site: https://playdeezgames.github.io/tggd_jamference2/"
