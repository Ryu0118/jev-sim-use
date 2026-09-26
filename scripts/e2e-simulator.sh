#!/usr/bin/env bash
# The primary end-to-end verification (see Testing in CLAUDE.md): the release jev-sim-use works through a fixed set of
# goals in the simulator's built-in Settings app, through the real sim-use and the real Jev API. Every goal is judged
# by reading the screen afterwards, never by the exit status alone. Not run in CI: it needs a booted simulator and
# spends real API calls. Paste the summary table it prints into every behaviour-changing PR.
#
# Usage: scripts/e2e-simulator.sh <udid> [-g goal[,goal...]] [-r repetitions]    (`--list` prints the goals)
#        mise run e2e -- <udid> [-g ...] [-r ...]
# Needs: sim-use, jq, perl, TYPESAFE_API_KEY (never printed). Settings is relaunched in English before every goal, so
# the simulator's own language does not matter.
# Artifacts: .e2e/<timestamp>/<goal>-r<n>/ (gitignored): exit status, stdout, stderr with each line's time since the
# start, the check results, `session show` when a session remains, the final `sim-use ui` reading, and a recording.
# E2E_OUTPUT overrides the directory; E2E_SKIP_BUILD=1 reuses the release binary.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/.build/release/jev-sim-use"
SETTINGS=com.apple.Preferences
GOALS=(route toggle scroll search hand-over already-met)

fail_setup() {
    echo "e2e: $*" >&2
    exit 2
}

usage() {
    sed -n '7,8p' "$0" | sed 's/^# //' >&2
    exit 64
}

# --- Arguments and preconditions -----------------------------------------------------------------------------------

if [[ ${1:-} == --list ]]; then
    printf '%s\n' "${GOALS[@]}"
    exit 0
fi
[[ $# -ge 1 && ${1:0:1} != - ]] || usage
DEVICE=$1
shift
selected=("${GOALS[@]}")
repetitions=1
while getopts "g:r:" option; do
    case $option in
    g) IFS=, read -r -a selected <<<"$OPTARG" ;;
    r) repetitions=$OPTARG ;;
    *) usage ;;
    esac
done
[[ $repetitions =~ ^[1-9][0-9]*$ ]] || fail_setup "-r takes a positive number."
for name in "${selected[@]}"; do
    [[ " ${GOALS[*]} " == *" $name "* ]] || fail_setup "unknown goal \"$name\"; goals: ${GOALS[*]}"
done

command -v sim-use >/dev/null || fail_setup "sim-use is not on PATH (brew install lycorp-jp/tap/sim-use)."
command -v jq >/dev/null || fail_setup "jq is not on PATH."
[[ -n ${TYPESAFE_API_KEY:-} ]] || fail_setup "TYPESAFE_API_KEY is not set."
xcrun simctl list devices booted -j | jq -e --arg d "$DEVICE" '[.devices[][] | select(.udid == $d)] | length == 1' \
    >/dev/null || fail_setup "no booted simulator has the udid $DEVICE."

if [[ ${E2E_SKIP_BUILD:-0} != 1 ]]; then
    (cd "$ROOT" && swift build -c release --product jev-sim-use >/dev/null) || fail_setup "the release build failed."
fi
[[ -x $BIN ]] || fail_setup "$BIN is missing; run without E2E_SKIP_BUILD."

OUT=${E2E_OUTPUT:-$ROOT/.e2e/$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
# Sessions go to a throwaway store, so the goals neither read nor delete the developer's own sessions.
export XDG_STATE_HOME="$OUT/state"

# --- Reading the screen --------------------------------------------------------------------------------------------

ui_json() {
    sim-use ui --device "$DEVICE" --json
}

# Whether the current screen has an element matching the jq condition `$1` (applied to each entry; `$a` is `$2`).
screen_has() {
    ui_json | jq -e --arg a "${2:-}" "[.data.entries[] | select($1)] | length > 0" >/dev/null
}

# shellcheck disable=SC2016 # `$a` is a jq variable.
heading_is() {
    screen_has '.role == "Heading" and .label == $a' "$1"
}

# The value of the element whose accessibility identifier is `$1` (a switch reads "1" or "0").
value_of() {
    ui_json | jq -r --arg a "$1" '[.data.entries[] | select(.uniqueId == $a)][0].value // empty'
}

wait_for_heading() {
    for _ in $(seq 1 20); do
        heading_is "$1" && return 0
        sleep 0.5
    done
    return 1
}

# --- Setup and restore ---------------------------------------------------------------------------------------------

# Relaunches Settings in English on its top screen, then taps each row in turn (sim-use cannot launch apps; simctl
# can). A row whose screen has another title is written `row=title`.
open_settings() {
    xcrun simctl terminate "$DEVICE" "$SETTINGS" >/dev/null 2>&1
    xcrun simctl launch "$DEVICE" "$SETTINGS" -AppleLanguages "(en)" -AppleLocale en_US >/dev/null || return 1
    wait_for_heading Settings || return 1
    for row in "$@"; do
        sim-use tap --label "${row%%=*}" --device "$DEVICE" --json >/dev/null || return 1
        wait_for_heading "${row#*=}" || return 1
    done
}

# Sets the switch with identifier `$1` to `$2` ("1" or "0") and confirms it on screen. iOS switches ignore a centre
# tap, so this taps the trailing edge with a short hold, as the tool itself does.
set_switch() {
    local id=$1 want=$2 x y
    [[ $(value_of "$id") == "$want" ]] && return 0
    read -r x y < <(ui_json | jq -r --arg a "$id" '[.data.entries[] | select(.uniqueId == $a)][0].frame
        | "\(.x + .width - 26) \(.y + .height / 2)"')
    SIM_USE_NO_DAEMON=1 sim-use tap -x "$x" -y "$y" --duration 0.05 --device "$DEVICE" --json >/dev/null
    sleep 1
    [[ $(value_of "$id") == "$want" ]]
}

# --- Recording a goal ----------------------------------------------------------------------------------------------

run_dir=""

check() {
    local description=$1
    shift
    if "$@" >>"$run_dir/check-output.txt" 2>&1; then
        echo "PASS  $description" >>"$run_dir/checks.txt"
    else
        echo "FAIL  $description" >>"$run_dir/checks.txt"
    fi
}

negate() {
    ! "$@"
}

# Runs jev-sim-use with `$@` under the prefix `$1`: stdout, stderr with each line's seconds since the start, and the
# exit status.
jsu() {
    local prefix=$1
    shift
    "$BIN" "$@" >"$run_dir/$prefix.stdout.txt" \
        2> >(perl -MTime::HiRes=time -e '$s = time; $| = 1; while (<STDIN>) { printf "%7.2f  %s", time - $s, $_ }' \
            >"$run_dir/$prefix.stderr.txt")
    echo $? >"$run_dir/$prefix.exit-status"
    wait
}

status_is() {
    [[ $(cat "$run_dir/$1.exit-status") == "$2" ]]
}

stdout_has() {
    grep -qF -- "$2" "$run_dir/$1.stdout.txt"
}

session_of() {
    sed -nE 's/^Session: ([0-9a-f]+)$/\1/p' "$run_dir/$1.stdout.txt"
}

session_exists() {
    "$BIN" session show "$1" >/dev/null 2>&1
}

# --- Goals ---------------------------------------------------------------------------------------------------------

# A route through three screens.
goal_route() {
    open_settings || return 1
    jsu run "In Settings, open General, then Keyboard, then Text Replacement" -d "$DEVICE" --max-steps 8
    check "exit status 0" status_is run 0
    check "the Text Replacement screen shows" heading_is "Text Replacement"
}

# A switch, which ignores a centre tap.
goal_toggle() {
    local id=KeyboardAutocorrection initial
    open_settings General Keyboard=Keyboards || return 1
    initial=$(value_of "$id")
    set_switch "$id" 1 || return 1
    jsu run "Turn off Auto-Correction" -d "$DEVICE" --max-steps 4
    check "exit status 0" status_is run 0
    check "the Auto-Correction switch reads off" test "$(value_of "$id")" = 0
    check "the keyboard settings still show" heading_is Keyboards
    check "the switch is restored to its value before the goal (${initial:-1})" set_switch "$id" "${initial:-1}"
}

# A row below the first screenful, which must be scrolled into reach.
goal_scroll() {
    open_settings || return 1
    jsu run "In Settings, open Privacy & Security" -d "$DEVICE" --max-steps 6 --actions tap,scroll
    check "exit status 0" status_is run 0
    check "the Privacy & Security screen shows" heading_is "Privacy & Security"
}

# Typing a named text into the search field, then Return. The goal names the search as one task: "enter the query into
# the search field, then press Return" made Jev answer BLOCKED over typing at step 1 in 3 of 5 runs. A Return pressed
# before typing is the known placeholder limit in CLAUDE.md.
goal_search() {
    open_settings || return 1
    jsu run "Search Settings for the query, then press Return" -t query=Keyboard \
        -d "$DEVICE" --max-steps 6 --actions tap,type,return
    check "exit status 0" status_is run 0
    check "the search field holds the query" screen_has '(.role == "TextField" or .role == "SearchField")
        and (.label == "Keyboard" or .value == "Keyboard")'
    # What the search finds depends on the simulator's search index (one returned "No Results"), not on this tool, so
    # the check is that the search ran: its results or its no-results message for the query show.
    check "the search for the query ran" screen_has '.role != "TextField" and .role != "SearchField"
        and ((.label // "") | contains("Keyboard"))'
    check "two actions ran: the typing and Return" stdout_has run "after 2 action(s)."
}

# An unreachable goal hands over; a supervisor's note makes the resumed run reach it.
goal_hand_over() {
    local session
    open_settings || return 1
    jsu run "Open the Teleport settings screen" -d "$DEVICE" --max-steps 6
    session=$(session_of run)
    check "the unreachable goal exits 1" status_is run 1
    check "it names the session to resume" test -n "$session"
    [[ -n $session ]] || return 0
    "$BIN" session tell "$session" -n "This device has no Teleport screen. For this check, the Teleport screen \
means the About screen under General; the goal is reached when the About screen shows." >"$run_dir/tell.stdout.txt"
    check "session tell adds the note" grep -q '^  1\. This device has no Teleport screen' "$run_dir/tell.stdout.txt"
    open_settings || return 1
    jsu resume session resume "$session" -d "$DEVICE" --max-steps 8
    check "the resumed run exits 0" status_is resume 0
    check "the About screen shows" heading_is About
    check "the finished session is deleted" negate session_exists "$session"
}

# A goal the start screen already meets.
goal_already_met() {
    open_settings General About || return 1
    jsu run "Show the About screen in General settings" -d "$DEVICE" --max-steps 3
    check "exit status 0" status_is run 0
    check "it finishes without acting" stdout_has run "Goal reached after 0 action(s)."
    check "the About screen still shows" heading_is About
}

# --- Driver --------------------------------------------------------------------------------------------------------

summary="$OUT/summary.md"
{
    echo "| Goal | Run | Result | Exit | Actions | Steps (s) | Wall (s) | Jev cost (USD) | Failed checks |"
    echo "|---|---|---|---|---|---|---|---|---|"
} >"$summary"
failed=0

for name in "${selected[@]}"; do
    for run in $(seq 1 "$repetitions"); do
        run_dir="$OUT/$name-r$run"
        mkdir -p "$run_dir"
        : >"$run_dir/checks.txt"
        echo "== $name (run $run)" >&2

        xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$run_dir/recording.mp4" >/dev/null 2>&1 &
        recorder=$!
        started=$(date +%s)
        "goal_${name//-/_}" || echo "FAIL  setup: could not reach the starting screen" >>"$run_dir/checks.txt"
        wall=$(($(date +%s) - started))
        kill -INT "$recorder" 2>/dev/null
        wait "$recorder" 2>/dev/null

        for prefix in run resume; do
            [[ -f $run_dir/$prefix.stdout.txt ]] || continue
            session=$(session_of "$prefix")
            if [[ -n $session ]] && session_exists "$session"; then
                "$BIN" session show "$session" >"$run_dir/session-show.txt"
            fi
        done
        ui_json >"$run_dir/ui.json" 2>&1
        sim-use ui --device "$DEVICE" >"$run_dir/ui.txt" 2>&1

        exits=$(cat "$run_dir"/run.exit-status "$run_dir"/resume.exit-status 2>/dev/null | paste -sd/ -)
        actions=$(cat "$run_dir"/run.stdout.txt "$run_dir"/resume.stdout.txt 2>/dev/null \
            | sed -nE 's/.*(after|at step) ([0-9]+).*/\2/p' | paste -sd/ -)
        steps=$(cat "$run_dir"/run.stderr.txt "$run_dir"/resume.stderr.txt 2>/dev/null \
            | sed -nE 's/^ *([0-9.]+)  \[([0-9]+)\] .*\(support.*/\2@\1/p' | paste -sd' ' -)
        cost=$(cat "$run_dir"/run.stderr.txt "$run_dir"/resume.stderr.txt 2>/dev/null \
            | sed -nE 's/.*~[$]([0-9.e-]+).*/\1/p' | awk '{ total += $1 } END { printf "%.6f", total }')
        failures=$(grep '^FAIL' "$run_dir/checks.txt" | cut -c7- | paste -sd';' -)
        result=PASS
        if [[ -n $failures ]]; then
            result=FAIL
            failed=$((failed + 1))
        fi
        echo "| $name | $run | $result | ${exits:--} | ${actions:--} | ${steps:--} | $wall | $cost | ${failures:--} |" \
            >>"$summary"
        sed 's/^/   /' "$run_dir/checks.txt" >&2
    done
done

echo
cat "$summary"
echo
echo "Steps (s): each planned step as <step>@<seconds since that command started>."
echo "Artifacts: $OUT"
[[ $failed -eq 0 ]]
