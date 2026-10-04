#!/usr/bin/env bash
# Tests, builds and zips the game. Publishing to itch.io needs --push, so a plain run never uploads.
#   ./shippit.sh          test, build, zip (writes build/roomba-rights-html5.zip), "not pushed"
#   ./shippit.sh --push   the same, then butler push to the itch.io html channel
# Only ever pass --push when the owner says so: it publishes the game.
set -euo pipefail
cd "$(dirname "$0")"
ODIN=${ODIN:-odin}
CHANNEL=thegrumpygamedev/roomba-rights-of-splorr:html # the itch.io page must already exist

"$ODIN" test src -define:ODIN_TEST_THREADS=1
rm -f odin # the test run leaves a stray binary named odin
ODIN="$ODIN" ./build.sh

ZIP=build/roomba-rights-html5.zip
rm -f "$ZIP"
(cd build/web && zip -qr "../roomba-rights-html5.zip" .) # index.html at the zip's root
echo "zipped $ZIP"

if [[ "${1:-}" == "--push" ]]; then
	butler push build/web "$CHANNEL"
else
	echo "not pushed (pass --push to upload to $CHANNEL)"
fi
