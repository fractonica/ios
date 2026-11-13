#!/bin/sh
# Renders every screen x mode x layout to PNG through the Mac build.
#
#   Tools/snapshot.sh                       -> build/snapshots, at SPEC vector A
#   Tools/snapshot.sh out/dir               -> another directory
#   Tools/snapshot.sh out/dir --t 1700000000 --theme basalt     extra launch arguments
#
# The app is started with --snapshot <dir>: it draws nothing on screen, writes
#   <screen>-<layout>-<mode>.png     now | ladder | lens | wave  x  phone | desktop  x  pure | earth
#   now-phone-pure-focus<L>.png      L = 0 3 5 6 7 9 12 13
#   ladder-<layout>-<mode>-rung<L>.png   L = 0 6 29 62 (top, the Helion, zeta-1, bottom)
#   lens-<layout>-<mode>-rung<L>.png     L = 0 6 12 13 29 30 62
#   wave-<layout>-<mode>-focus<L>.png    L = 3 6 9 (the wave re-scaled)
#   <screen>-<layout>-<mode>-scrubbed.png  every screen with the cursor away from now
# (phone 393 x 852 at 3x, desktop 1280 x 800 at 2x) and exits 0.
# Earth-mode pictures are rendered in UTC so that they do not depend on the
# machine's time zone; pass --zone <identifier> to change that.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build/snapshots}"
[ $# -gt 0 ] && shift
APP="$ROOT/build/DerivedData/Build/Products/Debug/Fractonica.app/Contents/MacOS/Fractonica"

if [ "${FRACTONICA_SKIP_BUILD:-0}" != "1" ]; then
    "$ROOT/Tools/build.sh" mac
fi

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
"$APP" --snapshot "$OUT" --zone UTC "$@"
echo "== snapshots in $OUT"
ls "$OUT"
