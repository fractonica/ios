#!/bin/sh
# Runs the FractonicaKit tests (swift test) on this Mac.
#
#   Tools/test-kit.sh                      all tests
#   Tools/test-kit.sh --filter SpecClock   one test class (any `swift test` argument is passed on)
#
# The kit depends on the sibling checkout ../core by path, so the tests also
# compile the C core. SPEC.md's vectors are typed into the tests literally:
# a failure here means the kit hands the core a wrong argument, or the core
# changed a reading.
set -eu

cd "$(dirname "$0")/../FractonicaKit"
exec swift test "$@"
