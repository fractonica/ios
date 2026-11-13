#!/bin/sh
# Runs the UI tests (AppUITests/) on the iPhone simulator: the app is launched
# at SPEC vector A and driven as a person would drive it (the limb, the mode,
# each screen, scrubbing the wave, back to NOW).
#
#   Tools/test-ui.sh                    on "iPhone 16 Pro" (or $FRACTONICA_SIMULATOR)
#   Tools/test-ui.sh "iPad (A16)"       on another simulator
#
# The result bundle (with a screenshot of each step) is build/ui-tests.xcresult.
# On the Mac the same tests need the Accessibility permission for the test
# runner, which a person must grant once:
#   xcodebuild -project Fractonica.xcodeproj -scheme FractonicaUITests \
#       -derivedDataPath build/DerivedData -destination platform=macOS test
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
UDID="$("$ROOT/Tools/simulator-id.sh" ${1:+"$1"})"
LOG="$ROOT/build/test-ui.log"
mkdir -p "$ROOT/build"
xcodegen generate --quiet
rm -rf "$ROOT/build/ui-tests.xcresult"
# xcodebuild's own status decides the script's (see Tools/test-app.sh).
status=0
xcodebuild -project Fractonica.xcodeproj -scheme FractonicaUITests -configuration Debug \
    -derivedDataPath "$ROOT/build/DerivedData" -destination "platform=iOS Simulator,id=$UDID" \
    -resultBundlePath "$ROOT/build/ui-tests.xcresult" test >"$LOG" 2>&1 || status=$?
grep -E "^(Test Suite|Test Case|/.*: error:|.*error:|[[:space:]]+Executed|\*\* TEST|.*BUILD FAILED)" "$LOG" || true
if [ "$status" -ne 0 ]; then
    echo "== UI tests FAILED (xcodebuild exit $status; full log: $LOG)"
fi
exit "$status"
