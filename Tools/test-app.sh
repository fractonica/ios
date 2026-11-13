#!/bin/sh
# Runs the app's unit tests (AppTests/) on this Mac: the readings the screens
# draw, checked against SPEC vector A, and the launch-argument parser.
#
#   Tools/test-app.sh
#
# The tests are hosted by the Mac app, so a window opens briefly.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOG="$ROOT/build/test-app.log"
mkdir -p "$ROOT/build"
xcodegen generate --quiet
# xcodebuild's own status decides the script's: the log is only filtered for
# the summary, never piped (a pipe would hand back grep's status instead).
status=0
xcodebuild -project Fractonica.xcodeproj -scheme Fractonica -configuration Debug \
    -derivedDataPath "$ROOT/build/DerivedData" -destination "platform=macOS" test >"$LOG" 2>&1 || status=$?
grep -E "^(Test Suite|Test Case .*failed|/.*: error:|[[:space:]]+Executed|\*\* TEST|.*BUILD FAILED)" "$LOG" || true
if [ "$status" -ne 0 ]; then
    echo "== app tests FAILED (xcodebuild exit $status; full log: $LOG)"
fi
exit "$status"
