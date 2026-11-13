#!/bin/sh
# Generates Fractonica.xcodeproj from project.yml and builds the app.
#
#   Tools/build.sh            both: the iPhone simulator and the Mac
#   Tools/build.sh ios        the iPhone simulator only ("iPhone 16 Pro", no signing)
#   Tools/build.sh mac        the Mac only (signed ad hoc)
#
# Output goes to build/DerivedData (git-ignored):
#   build/DerivedData/Build/Products/Debug/Fractonica.app                   (Mac)
#   build/DerivedData/Build/Products/Debug-iphonesimulator/Fractonica.app   (simulator)
#
# The script prints xcodebuild's warnings and errors and fails on either an
# error or a warning in our own Swift code (App/, AppTests/, FractonicaKit/).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
WHAT="${1:-all}"
SIMULATOR="${FRACTONICA_SIMULATOR:-iPhone 16 Pro}"

cd "$ROOT"
xcodegen generate --quiet

build() {
    label="$1"; shift
    log="$ROOT/build/build-$label.log"
    mkdir -p "$ROOT/build"
    echo "== building for $label"
    if ! xcodebuild -project Fractonica.xcodeproj -scheme Fractonica -configuration Debug \
            -derivedDataPath "$DERIVED" "$@" build >"$log" 2>&1; then
        grep -E "error:|warning:" "$log" | sort -u || true
        tail -n 5 "$log"
        echo "== $label: BUILD FAILED (full log: $log)"
        exit 1
    fi
    # Warnings in our own sources fail the build; the C core's are its own business.
    if grep -E "warning:" "$log" | grep -E "/ios/(App|AppTests|FractonicaKit)/" | sort -u | grep . ; then
        echo "== $label: warnings in our own code (full log: $log)"
        exit 1
    fi
    echo "== $label: BUILD SUCCEEDED, no warnings in our code"
}

case "$WHAT" in
    ios|all)
        # A name alone means "on the latest iOS", which that device may not
        # have: take the identifier of the newest simulator with this name.
        UDID="$("$ROOT/Tools/simulator-id.sh" "$SIMULATOR")"
        build ios -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO
        ;;
esac
case "$WHAT" in
    mac|all)
        build mac -destination "platform=macOS"
        ;;
esac
