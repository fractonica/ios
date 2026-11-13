#!/bin/sh
# Prints the identifier (UDID) of the newest available simulator with a name.
#
#   Tools/simulator-id.sh                  -> "iPhone 16 Pro" (or $FRACTONICA_SIMULATOR)
#   Tools/simulator-id.sh "iPhone 17 Pro"
#
# simctl lists runtimes oldest first, so the last match runs the newest iOS.
set -eu

NAME="${1:-${FRACTONICA_SIMULATOR:-iPhone 16 Pro}}"
UDID="$(xcrun simctl list devices available | grep -F "    $NAME (" | tail -n 1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [ -z "$UDID" ]; then
    echo "no available simulator named \"$NAME\"" >&2
    exit 1
fi
echo "$UDID"
