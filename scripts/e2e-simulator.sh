#!/usr/bin/env bash
# Manual end-to-end cases against a REAL simulator: the release jev-sim-use drives Apple's Settings app on a booted iOS
# simulator through the real sim-use and the real Jev API. Not run in CI; every run spends real API calls. The CI
# end-to-end suite is scripts/e2e.sh (`mise run e2e`), which fakes sim-use and Jev. Every case here records artifacts
# and is judged by reading the screen afterwards, never by the exit status alone. See the Testing section of CLAUDE.md.
#
# Usage: scripts/e2e-simulator.sh [case...]    (default: every case; `--list` prints them)
# Needs: sim-use, jq, TYPESAFE_API_KEY, and one booted iOS simulator in English (or SIM_USE_DEVICE naming one).
# Artifacts: .e2e/simulator-<timestamp>/<case>/ (gitignored); E2E_OUTPUT overrides the directory, E2E_SKIP_BUILD=1
# reuses the existing release binary.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/.build/release/jev-sim-use"
OUT=${E2E_OUTPUT:-$ROOT/.e2e/simulator-$(date +%Y%m%d-%H%M%S)}
SETTINGS=com.apple.Preferences
CASES=(navigate toggle back search hand-over actions already-done)

fail_setup() {
    echo "e2e: $*" >&2
    exit 2
}

# --- Preconditions -------------------------------------------------------------------------------------------------

if [[ ${1:-} == --list ]]; then
    printf '%s\n' "${CASES[@]}"
    exit 0
fi
selected=("$@")
[[ $# -gt 0 ]] || selected=("${CASES[@]}")
for name in "${selected[@]}"; do
    [[ " ${CASES[*]} " == *" $name "* ]] || fail_setup "unknown case \"$name\"; cases: ${CASES[*]}"
done

command -v sim-use >/dev/null || fail_setup "sim-use is not on PATH (brew install lycorp-jp/tap/sim-use)."
command -v jq >/dev/null || fail_setup "jq is not on PATH."
[[ -n ${TYPESAFE_API_KEY:-} ]] || fail_setup "TYPESAFE_API_KEY is not set."

DEVICE=${SIM_USE_DEVICE:-}
if [[ -z $DEVICE ]]; then
    booted=$(xcrun simctl list devices booted -j | jq -r '.devices | to_entries[] | select(.key | test("iOS")) | .value[].udid')
    count=$(grep -c . <<<"$booted")
    if [[ $count -eq 0 ]]; then
        echo "SKIP: no booted iOS simulator. Boot one (xcrun simctl boot <udid>) or set SIM_USE_DEVICE, then run again."
        exit 0
    fi
    [[ $count -eq 1 ]] || fail_setup "$count iOS simulators are booted; set SIM_USE_DEVICE to the one to drive."
    DEVICE=$booted
fi
language=$(xcrun simctl spawn "$DEVICE" defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n()"')
[[ $language == en* ]] || fail_setup "the goals and checks read English labels, but the simulator's language is \
\"${language:-unknown}\". Run: xcrun simctl spawn $DEVICE defaults write -g AppleLanguages -array en-US, then reboot it."

if [[ ${E2E_SKIP_BUILD:-0} != 1 ]]; then
    (cd "$ROOT" && swift build -c release --product jev-sim-use >/dev/null) || fail_setup "the release build failed."
fi
[[ -x $BIN ]] || fail_setup "$BIN is missing; run without E2E_SKIP_BUILD."

mkdir -p "$OUT"
# Sessions go to a throwaway store, so the cases neither read nor delete the developer's own sessions.
export XDG_STATE_HOME="$OUT/state"

# --- Reading the screen --------------------------------------------------------------------------------------------

ui_json() {
    sim-use ui --device "$DEVICE" --json
}

# Whether the current screen has an element matching the jq condition `$1` (applied to each entry).
screen_has() {
    ui_json | jq -e --arg a "${2:-}" "[.data.entries[] | select($1)] | length > 0" >/dev/null
}

# shellcheck disable=SC2016 # `$a` is a jq variable.
heading_is() {
    screen_has '.role == "Heading" and .label == $a' "$1"
}

# shellcheck disable=SC2016
back_is() {
    screen_has '.uniqueId == "BackButton" and .label == $a' "$1"
}

# The value of the element whose accessibility identifier is `$1` (a switch reads "1" or "0").
value_of() {
    ui_json | jq -r --arg a "$1" '[.data.entries[] | select(.uniqueId == $a)][0].value // empty'
}

wait_for_heading() {
    for _ in $(seq 1 10); do
        heading_is "$1" && return 0
        sleep 0.5
    done
    return 1
}

# --- Setup and restore ---------------------------------------------------------------------------------------------

# Relaunches Settings on its top screen, then taps each row in turn; sim-use cannot launch apps, simctl can. A row
# whose screen has another title is written `row=title`.
open_settings() {
    xcrun simctl terminate "$DEVICE" "$SETTINGS" >/dev/null 2>&1
    xcrun simctl launch "$DEVICE" "$SETTINGS" >/dev/null || return 1
    wait_for_heading Settings || return 1
    for row in "$@"; do
        sim-use tap --label "${row%%=*}" --device "$DEVICE" --json >/dev/null || return 1
        wait_for_heading "${row#*=}" || return 1
    done
}

# Sets the switch with identifier `$1` to `$2` ("1" or "0") and confirms it on screen. iOS switches ignore a
# centre tap, so this taps the trailing edge with a short hold, as the tool itself does.
set_switch() {
    local id=$1 want=$2 frame
    [[ $(value_of "$id") == "$want" ]] && return 0
    frame=$(ui_json | jq -r --arg a "$id" '[.data.entries[] | select(.uniqueId == $a)][0].frame
        | "\(.x + .width - 26) \(.y + .height / 2)"')
    read -r x y <<<"$frame"
    SIM_USE_NO_DAEMON=1 sim-use tap -x "$x" -y "$y" --duration 0.05 --device "$DEVICE" --json >/dev/null
    sleep 1
    [[ $(value_of "$id") == "$want" ]]
}

# --- Recording a case ----------------------------------------------------------------------------------------------

case_dir=""
case_failures=0

negate() {
    ! "$@"
}

check() {
    local description=$1
    shift
    if "$@"; then
        echo "PASS  $description" >>"$case_dir/checks.txt"
    else
        echo "FAIL  $description" >>"$case_dir/checks.txt"
        case_failures=$((case_failures + 1))
    fi
}

# Runs jev-sim-use with `$@`, keeping stdout, stderr (the step lines), and the exit status under the prefix `$1`.
jsu() {
    local prefix=$1
    shift
    "$BIN" "$@" >"$case_dir/$prefix.stdout.txt" 2>"$case_dir/$prefix.stderr.txt"
    echo $? >"$case_dir/$prefix.exit-status"
}

status_of() {
    cat "$case_dir/$1.exit-status"
}

# The actions of the planned step lines, such as `Tap the Button labelled "General"`, one per line.
planned_actions() {
    sed -nE 's/^\[[0-9]+\] (.*) \(support .*/\1/p' "$case_dir/$1.stderr.txt"
}

no_results_message() {
    screen_has '(.label // "") | startswith("No Results")'
}

# Whether the last text entry was followed by Return, and nothing but Done came after it.
return_after_entry() {
    planned_actions run | grep -v '^Done$' | tail -2 | paste -sd'|' - | grep -qx 'Enter the query into .*|Press Return'
}

only_taps_planned() {
    ! planned_actions run | grep -qvE '^(Tap |Done$|Nothing$)'
}

session_exists() {
    "$BIN" session show "$1" >/dev/null 2>&1
}

# --- Cases ---------------------------------------------------------------------------------------------------------

case_navigate() {
    open_settings || return 1
    jsu run "In Settings, open General, then Keyboard, then Text Replacement" -d "$DEVICE" --max-steps 8
    check "exit status 0" test "$(status_of run)" = 0
    check "the Text Replacement screen shows" heading_is "Text Replacement"
    check "its back button leads to the keyboard settings" back_is Keyboards
}

case_toggle() {
    local id=KeyboardAutocorrection initial
    open_settings General Keyboard=Keyboards || return 1
    initial=$(value_of "$id")
    set_switch "$id" 1 || return 1
    jsu run "Turn off Auto-Correction" -d "$DEVICE" --max-steps 4
    check "exit status 0" test "$(status_of run)" = 0
    check "the Auto-Correction switch reads off" test "$(value_of "$id")" = 0
    check "the keyboard settings still show" heading_is Keyboards
    check "the switch is restored to its value before the case (${initial:-1})" set_switch "$id" "${initial:-1}"
}

case_back() {
    open_settings General About || return 1
    jsu run "Go back to the General settings screen" -d "$DEVICE" --max-steps 3 --actions back,tap
    check "exit status 0" test "$(status_of run)" = 0
    check "the General screen shows" heading_is General
    check "its About row shows" screen_has '.label == "About"'
}

case_search() {
    open_settings || return 1
    jsu run "In Settings, enter the query into the search field, then press Return" -t query=Keyboard \
        -d "$DEVICE" --max-steps 6 --actions tap,type,return
    check "exit status 0" test "$(status_of run)" = 0
    check "the search field holds the query" screen_has '(.role == "TextField" or .role == "SearchField")
        and (.label == "Keyboard" or .value == "Keyboard")'
    check "a result other than the field mentions the query" screen_has '.role != "TextField"
        and .role != "SearchField" and ((.label // "") | contains("Keyboard"))'
    check "no \"No Results\" message shows" negate no_results_message
    check "Return was pressed after the query was entered" return_after_entry
}

case_hand_over() {
    local session
    open_settings || return 1
    jsu run "Open the Teleport settings screen" -d "$DEVICE" --max-steps 6
    session=$(sed -nE 's/^Session: ([0-9a-f]+)$/\1/p' "$case_dir/run.stdout.txt")
    check "the unreachable goal exits 1" test "$(status_of run)" = 1
    check "it names the session to resume" test -n "$session"
    [[ -n $session ]] || return 0

    "$BIN" session show "$session" >"$case_dir/show.stdout.txt" 2>&1
    check "session show lists the goal" grep -q '^Goal: Open the Teleport settings screen$' "$case_dir/show.stdout.txt"
    check "session show lists the stopped run" grep -qE '^  1\. .*action\(s\): ' "$case_dir/show.stdout.txt"

    "$BIN" session tell "$session" -n "This device has no Teleport screen. For this check, the Teleport screen \
means the About screen under General; the goal is reached when the About screen shows." \
        >"$case_dir/tell.stdout.txt" 2>&1
    check "session tell adds the note" grep -q '^  1\. This device has no Teleport screen' "$case_dir/tell.stdout.txt"

    jsu resume session resume "$session" -d "$DEVICE" --max-steps 8
    check "the resumed run exits 0" test "$(status_of resume)" = 0
    check "the About screen shows" heading_is About
    check "the finished session is deleted" negate session_exists "$session"
}

case_actions() {
    open_settings || return 1
    jsu run "In Settings, open Accessibility, then Display & Text Size" -d "$DEVICE" --max-steps 6 --actions tap
    check "exit status 0" test "$(status_of run)" = 0
    check "the Display & Text Size screen shows" heading_is "Display & Text Size"
    check "every planned action is a tap, Done, or a hand-over" only_taps_planned
}

case_already_done() {
    open_settings General About || return 1
    jsu run "Show the About screen in General settings" -d "$DEVICE" --max-steps 3
    check "exit status 0" test "$(status_of run)" = 0
    check "it finishes without acting" grep -qx 'Goal reached after 0 action(s).' "$case_dir/run.stdout.txt"
    check "the About screen still shows" heading_is About
}

# --- Driver --------------------------------------------------------------------------------------------------------

summary="$OUT/summary.md"
{
    echo "| Case | Result | Exit | Actions | Seconds | Failed checks |"
    echo "|---|---|---|---|---|---|"
} >"$summary"
failed=0

for name in "${selected[@]}"; do
    case_dir="$OUT/$name"
    case_failures=0
    mkdir -p "$case_dir"
    : >"$case_dir/checks.txt"
    echo "== $name" >&2

    sim-use record-video --device "$DEVICE" --output "$case_dir/video.mp4" >/dev/null 2>&1 &
    recorder=$!
    started=$(date +%s)
    if ! "case_${name//-/_}"; then
        echo "FAIL  setup: could not reach the starting screen" >>"$case_dir/checks.txt"
        case_failures=$((case_failures + 1))
    fi
    seconds=$(($(date +%s) - started))
    kill -INT "$recorder" 2>/dev/null
    wait "$recorder" 2>/dev/null

    ui_json >"$case_dir/ui.json" 2>&1
    sim-use ui --device "$DEVICE" >"$case_dir/ui.txt" 2>&1
    exits=$(cat "$case_dir"/*.exit-status 2>/dev/null | paste -sd/ -)
    actions=$(cat "$case_dir"/*.stdout.txt 2>/dev/null | sed -nE 's/.*(after|at step) ([0-9]+).*/\2/p' | paste -sd/ -)
    failures=$(grep '^FAIL' "$case_dir/checks.txt" | cut -c7- | paste -sd';' -)
    result=PASS
    if [[ $case_failures -gt 0 ]]; then
        result=FAIL
        failed=$((failed + 1))
    fi
    echo "| $name | $result | ${exits:--} | ${actions:--} | $seconds | ${failures:--} |" >>"$summary"
    sed 's/^/   /' "$case_dir/checks.txt" >&2
done

echo
cat "$summary"
echo
echo "Artifacts: $OUT"
[[ $failed -eq 0 ]]
