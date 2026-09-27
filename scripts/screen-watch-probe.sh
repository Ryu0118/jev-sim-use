#!/usr/bin/env bash
# Measures how soon the screen-change watcher sees a tap's effect: watches a booted iOS simulator's screen image with
# the hidden `jev-sim-use watch-screen`, taps a point through sim-use, and prints when the tap was sent and returned,
# the first change after it was sent, and the last change within the watch (the screen settling).
#
# Usage: scripts/screen-watch-probe.sh <udid> <x> <y> [seconds]
# Needs: sim-use and a built jev-sim-use (JEV_SIM_USE, default .build/release/jev-sim-use). The tap lands wherever
# the point is, so choose one whose effect is harmless.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=${JEV_SIM_USE:-"$ROOT/.build/release/jev-sim-use"}
[[ $# -ge 3 ]] || { sed -n '6p' "$0" >&2; exit 64; }
UDID=$1 X=$2 Y=$3 SECONDS_TO_WATCH=${4:-8}
[[ -x $BIN ]] || { echo "screen-watch-probe: build $BIN first (swift build -c release)" >&2; exit 2; }

changes=$(mktemp)
trap 'rm -f "$changes"' EXIT
"$BIN" watch-screen --device "$UDID" --seconds "$SECONDS_TO_WATCH" >"$changes" &
watcher=$!
# Let the watcher attach and the screen go quiet before the tap.
sleep 2
sent=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
sim-use tap -x "$X" -y "$Y" --device "$UDID" --json >/dev/null
returned=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
wait "$watcher"

awk -v sent="$sent" -v returned="$returned" '
    $1 == "changed" && $2 >= sent { if (!first) first = $2; last = $2; count++ }
    END {
        printf "tap sent %s, returned after %.3f s\n", sent, returned - sent
        if (!first) { print "no change after the tap"; exit }
        printf "first change %.3f s after sending, last %.3f s (%d changes)\n", first - sent, last - sent, count
    }
' "$changes"
