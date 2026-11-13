#!/bin/sh
# Installs the simulator build on a simulator and screenshots every screen in
# both modes at a pinned instant (default: SPEC vector A, UTC).
#
#   Tools/simulator-shots.sh                         "iPhone 16 Pro" -> build/screenshots/iPhone-16-Pro/
#   Tools/simulator-shots.sh "iPhone 16e"            another simulator
#   Tools/simulator-shots.sh "iPad (A16)" --t 946684800     extra launch arguments
#
# Builds nothing: run Tools/build.sh ios first. The simulator is booted if it
# is not, and left running (xcrun simctl shutdown <udid> to stop it).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-${FRACTONICA_SIMULATOR:-iPhone 16 Pro}}"
[ $# -gt 0 ] && shift
UDID="$("$ROOT/Tools/simulator-id.sh" "$NAME")"
APP="$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/Fractonica.app"
OUT="$ROOT/build/screenshots/$(echo "$NAME" | tr ' ()' '---' | sed -E 's/-+/-/g; s/-$//')"
BUNDLE=org.fractonica.clock

mkdir -p "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
for screen in now ladder lens wave; do
    for mode in pure earth; do
        xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
        xcrun simctl launch "$UDID" "$BUNDLE" --t 1791460800 --zone UTC --screen "$screen" --mode "$mode" "$@" >/dev/null
        sleep 2
        xcrun simctl io "$UDID" screenshot "$OUT/$screen-$mode.png" >/dev/null 2>&1
        echo "$OUT/$screen-$mode.png"
    done
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
