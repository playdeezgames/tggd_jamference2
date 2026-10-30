#!/usr/bin/env bash
# Prepares the itch.io build: tests, a size-optimised web build, a zip. Pushes ONLY with --push. Never commits,
# never deletes anything but its own zip. Usage: tools/ship.sh [--push]
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN=${ODIN:-odin}
# The page: https://thegrumpygamedev.itch.io/roomba-rights-of-splorr
TARGET="thegrumpygamedev/roomba-rights-of-splorr:html"
ZIP="build/roomba-rights-html5.zip"

"$ODIN" test src -define:ODIN_TEST_THREADS=1
rm -f odin # the test run leaves a stray binary named odin
ODIN="$ODIN" OPT=size ./build.sh
rm -f "$ZIP"
(cd build/web && zip -q -9 -r "../roomba-rights-html5.zip" .) # index.html at the zip's root
echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1)); wasm $(du -h build/web/game.wasm | cut -f1)"
unzip -l "$ZIP" | tail -8

if [[ "${1:-}" == "--push" ]]; then
	if [[ -n "$(git status --porcelain)" ]]; then echo "note: the working tree has uncommitted changes; what is pushed is the working tree, not a commit"; fi
	butler push build/web "$TARGET"
	echo "pushed to $TARGET. It goes live after itch.io processes it; check: butler status $TARGET"
else
	echo "not pushed (run tools/ship.sh --push when you want it live; the target is $TARGET)"
fi
