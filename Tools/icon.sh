#!/bin/sh
# Draws the app icon with the instrument's own renderer and cuts the sizes of
# App/Resources/Assets.xcassets/AppIcon.appiconset from it.
#
#   Tools/icon.sh                  the hero ring of a Helion at SPEC vector A
#   Tools/icon.sh --t 946684800    at another instant (any launch argument is passed on)
#
# The app is started with --icon <dir> (App/Snapshot/IconRenderer.swift): it
# writes icon-ios.png (1024, full bleed, no alpha) and icon-mac.png (1024, the
# rounded plate inside a Mac icon's margins) and exits. The PNGs in the asset
# catalog are committed, so run this only when the drawing changes, then build.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Debug/Fractonica.app/Contents/MacOS/Fractonica"
SET="$ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
WORK="$ROOT/build/icon"

if [ "${FRACTONICA_SKIP_BUILD:-0}" != "1" ]; then
    "$ROOT/Tools/build.sh" mac
fi

mkdir -p "$WORK" "$SET"
"$APP" --icon "$WORK" "$@"

cp "$WORK/icon-ios.png" "$SET/icon-ios-1024.png"
for size in 16 32 64 128 256 512 1024; do
    sips -z "$size" "$size" "$WORK/icon-mac.png" --out "$SET/icon-mac-$size.png" >/dev/null
done

cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-ios-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-mac-16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-mac-32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-mac-32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-mac-64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-mac-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-mac-256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-mac-256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-mac-512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-mac-512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-mac-1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
echo "== icon set written to $SET"
ls "$SET"
