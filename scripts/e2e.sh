#!/usr/bin/env bash
# End-to-end cases for the release jev-sim-use, run in CI (`mise run e2e`). Each case runs the real binary against a
# fake `sim-use` on PATH (scripts/e2e/fake-sim-use, a scripted screen state machine that records every call) and a
# local stub Jev server (scripts/e2e/stub-jev, scripted answers that record every request body). Checks read the exit
# status, stdout, stderr, the recorded sim-use calls, the request bodies, and the session files. See the Testing
# section of CLAUDE.md; scripts/e2e-simulator.sh is the manual counterpart on a real simulator.
#
# Usage: scripts/e2e.sh [case...]    (default: every case; `--list` prints them)
# Needs: python3 and jq. Artifacts: .e2e/<timestamp>/<case>/ (gitignored); E2E_OUTPUT overrides the directory, and
# E2E_SKIP_BUILD=1 reuses the existing release binary.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
E2E="$ROOT/scripts/e2e"
BIN="$ROOT/.build/release/jev-sim-use"
OUT=${E2E_OUTPUT:-$ROOT/.e2e/$(date +%Y%m%d-%H%M%S)}
DEVICE="E2E-DEVICE"
# The fake's default device, as a jq object, for scenarios that list several.
SIMULATOR='{deviceId: "E2E-DEVICE", kind: "simulator", name: "E2E Phone", platform: "ios", state: "Booted"}'
CASES=(tap-to-goal toggle-and-back reveal-covered-row type-and-return soft-keyboard hand-over-and-resume unsure-done
    blocked no-effect-repeat ticking-repeat destructive-bar app-disappears step-limit hint-retry menu-backdrop doctor exec skill
    setup-errors runtime-errors)

fail_setup() {
    echo "e2e: $*" >&2
    exit 2
}

if [[ ${1:-} == --list ]]; then
    printf '%s\n' "${CASES[@]}"
    exit 0
fi
selected=("$@")
[[ $# -gt 0 ]] || selected=("${CASES[@]}")
for name in "${selected[@]}"; do
    [[ " ${CASES[*]} " == *" $name "* ]] || fail_setup "unknown case \"$name\"; cases: ${CASES[*]}"
done
command -v python3 >/dev/null || fail_setup "python3 is not on PATH."
command -v jq >/dev/null || fail_setup "jq is not on PATH."
if [[ ${E2E_SKIP_BUILD:-0} != 1 ]]; then
    (cd "$ROOT" && swift build -c release --product jev-sim-use >/dev/null) || fail_setup "the release build failed."
fi
[[ -x $BIN ]] || fail_setup "$BIN is missing; run without E2E_SKIP_BUILD."
mkdir -p "$OUT"

# --- Per-case environment ------------------------------------------------------------------------------------------

case_dir=""
stub_pid=""
URL=""

# Starts the stub Jev server for the case's scenario and waits for its port: up to 60 s, since a cold CI runner
# starting every case's Python at once took longer than 5 s.
start_stub() {
    "$E2E/stub-jev" "$case_dir/scenario.json" "$case_dir/jev" 2>"$case_dir/jev/server.log" &
    stub_pid=$!
    for _ in $(seq 1 3000); do
        [[ -f $case_dir/jev/port ]] && break
        kill -0 "$stub_pid" 2>/dev/null || break
        sleep 0.02
    done
    if [[ ! -f $case_dir/jev/port ]]; then
        echo "FAIL  setup: the stub Jev server did not start ($(tr '\n' ' ' <"$case_dir/jev/server.log"))" \
            >>"$case_dir/checks.txt"
        return 1
    fi
    URL="http://127.0.0.1:$(cat "$case_dir/jev/port")"
}

stop_stub() {
    [[ -n $stub_pid ]] && kill "$stub_pid" 2>/dev/null && wait "$stub_pid" 2>/dev/null
    stub_pid=""
}

# Prepares the case directory from scripts/e2e/cases/<scenario>.json, changed by the optional jq filter `$2`. Called
# again within a case, it starts over: a fresh screen, call log, stub, and session store.
use_scenario() {
    stop_stub
    rm -rf "$case_dir/sim" "$case_dir/jev" "$case_dir/state"
    mkdir -p "$case_dir/bin" "$case_dir/sim" "$case_dir/jev" "$case_dir/home"
    jq "${2:-.}" "$E2E/cases/$1.json" >"$case_dir/scenario.json" || return 1
    cp "$E2E/fake-sim-use" "$case_dir/bin/sim-use"
    start_stub
}

# Runs jev-sim-use with `$@` in a clean environment: only the fake sim-use on PATH, a throwaway HOME and XDG
# directories, and a dummy API key. JSU_NO_KEY=1 leaves the key out and JSU_PATH replaces PATH. Keeps stdout,
# stderr, and the exit status under the prefix `$1`.
jsu() {
    local prefix=$1
    shift
    local environment=(
        "PATH=${JSU_PATH:-$case_dir/bin:/usr/bin:/bin}" "HOME=$case_dir/home" "XDG_STATE_HOME=$case_dir/state"
        "XDG_CONFIG_HOME=$case_dir/config" "E2E_SCENARIO=$case_dir/scenario.json" "E2E_STATE=$case_dir/sim"
    )
    [[ ${JSU_NO_KEY:-0} == 1 ]] || environment+=("TYPESAFE_API_KEY=e2e-dummy-key")
    env -i "${environment[@]}" "$BIN" "$@" >"$case_dir/$prefix.stdout.txt" 2>"$case_dir/$prefix.stderr.txt"
    echo $? >"$case_dir/$prefix.exit-status"
}

# --- Checks --------------------------------------------------------------------------------------------------------

check() {
    local description=$1
    shift
    if "$@" >>"$case_dir/check-output.txt" 2>&1; then
        echo "PASS  $description" >>"$case_dir/checks.txt"
    else
        echo "FAIL  $description" >>"$case_dir/checks.txt"
    fi
}

negate() {
    ! "$@"
}

status_is() {
    [[ $(cat "$case_dir/$1.exit-status") == "$2" ]]
}

stdout_is() {
    diff <(printf '%s\n' "${@:2}") "$case_dir/$1.stdout.txt"
}

stdout_has() {
    grep -qF -- "$2" "$case_dir/$1.stdout.txt"
}

stderr_has() {
    grep -qF -- "$2" "$case_dir/$1.stderr.txt"
}

# The sim-use calls the fake counts as actions, one per line without `--device <id> --json`, marked when they ran outside the daemon.
actions() {
    [[ -f $case_dir/sim/calls.jsonl ]] || return 0
    jq -r --arg d "$DEVICE" 'select(.kind == "action")
        | ([.args[] | select(. != "--device" and . != $d and . != "--json")] | join(" "))
        + (if .env.SIM_USE_NO_DAEMON == "1" then "  [no daemon]" else "" end)' "$case_dir/sim/calls.jsonl"
}

actions_are() {
    diff <(printf '%s\n' "$@" | sed '/^$/d') <(actions)
}

# Whether any sim-use call ran with exactly the arguments `$@` (the device and --json included).
called_with() {
    jq -e --argjson a "$(printf '%s\n' "$@" | jq -R . | jq -sc .)" 'select(.args == $a)' "$case_dir/sim/calls.jsonl" \
        | grep -q .
}

request_count_is() {
    [[ $(find "$case_dir/jev/requests" -name '*.json' 2>/dev/null | wc -l | tr -d ' ') == "$1" ]]
}

# Whether request `$1`'s body satisfies the jq condition `$2`.
request_has() {
    jq -e "$2" "$case_dir/jev/requests/$1.json" >/dev/null
}

request_lacks() {
    ! grep -qF -- "$2" "$case_dir/jev/requests/$1.json"
}

no_request_contains() {
    ! grep -qF -- "$1" "$case_dir"/jev/requests/*.json
}

stub_had_no_errors() {
    [[ ! -s $case_dir/jev/stub-errors.txt ]]
}

sessions_are() {
    [[ $(find "$case_dir/state/jev-sim-use/sessions" -name '*.json' 2>/dev/null | wc -l | tr -d ' ') == "$1" ]]
}

session_id() {
    sed -nE 's/^Session: ([0-9a-f]+)$/\1/p' "$case_dir/$1.stdout.txt"
}

# The checks every run that reaches Jev shares: the stub answered every request as scripted, and the status bar's
# ticking clock, which the fake adds to every screen, never reached Jev.
common_run_checks() {
    check "the stub answered every request from its script" stub_had_no_errors
    check "the status bar's clock never reaches Jev" no_request_contains " AM\""
}

# --- Cases: the agent loop -----------------------------------------------------------------------------------------

case_tap_to_goal() {
    use_scenario tap-to-goal || return 1
    jsu config config set base-url "$URL"
    jsu insecure config set base-url http://example.com
    jsu list config list
    jsu model config get model
    jsu run "Open the details screen"
    check "config set exits 0" status_is config 0
    check "config refuses a non-loopback http base URL" status_is insecure 64
    check "config list prints the stored value" stdout_is list "base-url=$URL"
    check "config get exits 1 for an unset key" status_is model 1
    check "exit status 0" status_is run 0
    check "stdout is the outcome alone" stdout_is run "Goal reached after 1 action(s)."
    check "stderr names the device and the endpoint from the config file" \
        stderr_has run "Device: E2E Phone (E2E-DEVICE); Jev: $URL/v1/systemone"
    check "support is the weaker of operation and target" \
        stderr_has run '[1] Tap the Button labelled "Open details" (support 0.80 [operation 0.95, element 0.80]'
    check "stderr logs the DONE step" stderr_has run "[2] Done (support 0.90"
    check "the only action is a tap by alias, outside the daemon" actions_are "tap @3  [no daemon]"
    check "Jev is asked again after the action it expected to finish the goal" request_count_is 2
    check "the request carries the goal" request_has 1 '.state.goal == "Open the details screen"'
    # shellcheck disable=SC2016 # the backticks are part of the text the questions open with.
    check "the rules travel once in the state and every question points at them" request_has 1 \
        '(.state.rules | length > 0) and ([.questions[].instructions | startswith("Follow `rules`")] | all)'
    check "the heading is not offered as a target" request_has 1 '.questions.element_target.criteria | has("e2") | not'
    check "the second request records the tap's effect" request_has 2 '.state.history[0].result == "screen changed"'
    check "the second request names the screen and where back leads" \
        request_has 2 '.state.screen.title == "Details" and .state.screen.back == "Inbox"'
    check "reaching the goal deletes the session" sessions_are 0
    common_run_checks
}

case_toggle_and_back() {
    use_scenario toggle-and-back || return 1
    jsu run run "Turn on dark mode, then go back home" --base-url "$URL"
    check "exit status 0" status_is run 0
    check "stdout is the outcome alone" stdout_is run "Goal reached after 2 action(s)."
    check "the switch is tapped on its trailing edge with a short hold, and back taps the back button" actions_are \
        "tap -x 360.0 -y 222.0 --duration 0.05  [no daemon]" "tap @2  [no daemon]"
    check "the switch reads off, not 0" request_has 1 '.state.screen.elements[] | select(.label == "Dark mode") | .value == "off"'
    check "the back button is left to go_back" request_has 1 '(.questions.element_target.criteria | has("e2") | not)
        and (.questions.operation.criteria | has("go_back"))'
    check "go_back is not offered without a back button" request_has 3 '.questions.operation.criteria | has("go_back") | not'
    common_run_checks
}

case_reveal_covered_row() {
    use_scenario reveal-covered-row || return 1
    jsu run run "Open the hidden row" --base-url "$URL"
    check "exit status 0" status_is run 0
    check "the row under the search field is marked covered" \
        request_has 1 '.state.screen.elements[] | select(.label == "Hidden row") | .covered_by == "Search"'
    check "the row is scrolled into reach, then tapped at its new alias" actions_are \
        "gesture scroll-up --duration 1.5" "tap @6  [no daemon]"
    check "the screen is read between the scroll and the tap" called_with ui --device "$DEVICE" --json
    check "history records the tap" request_has 2 '.state.history[0].action == "Tap the Button labelled \"Hidden row\""'
    common_run_checks

    use_scenario reveal-offscreen-switch || return 1
    jsu switch run "Turn on reminders" --base-url "$URL"
    check "a switch below the screen: exit status 0" status_is switch 0
    check "it is scrolled into reach, then tapped on its trailing edge with a short hold" actions_are \
        "gesture scroll-up --duration 1.5" "tap -x 360.0 -y 522.0 --duration 0.05  [no daemon]"
    common_run_checks
}

case_type_and_return() {
    use_scenario type-and-return || return 1
    jsu run run "Search for the query" -t query=needle-4711 --actions tap,type,return --base-url "$URL"
    check "exit status 0" status_is run 0
    check "stdout is the outcome alone" stdout_is run "Goal reached after 2 action(s)."
    check "the field is tapped, the value pasted after --, and Return pressed" actions_are \
        "tap @3  [no daemon]" "paste -- needle-4711" "ios key 40"
    check "a typing step logs each answer its support depends on" \
        stderr_has run "[1] Enter the query into \"Search\" (support 0.90 [operation 0.90, field 0.95, text 1.00]"
    check "the keyboard is checked before pasting" called_with keyboard-state --device "$DEVICE" --json
    check "--actions narrows the offered operations" request_has 1 \
        '[.questions.operation.criteria | keys[]] | sort == ["blocked", "done", "enter_text", "press_return", "tap"]'
    check "texts are offered by name only" request_has 1 '.questions.text_to_enter.criteria | keys == ["query"]'
    check "the value never reaches Jev before it is on screen" request_lacks 1 needle-4711
    check "the field showing the value carries the text's name" \
        request_has 2 '.state.screen.elements[] | select(.label == "Search") | .shows_text == ["query"]'
    common_run_checks
}

case_soft_keyboard() {
    use_scenario soft-keyboard || return 1
    jsu run run "Fill in the name" -t "name=Sample Name" --base-url "$URL"
    check "exit status 2 (setup)" status_is run 2
    check "stderr says a hardware keyboard is needed" stderr_has run "Entering text needs a hardware keyboard"
    check "the field is tapped but nothing is pasted" actions_are "tap @3  [no daemon]"
    common_run_checks
}

case_hand_over_and_resume() {
    local id
    use_scenario hand-over-and-resume || return 1
    jsu run run "Open the profile" --base-url "$URL"
    id=$(session_id run)
    check "exit status 1" status_is run 1
    check "stdout gives the reason and the session" stdout_is run \
        "Stopped at step 1: Jev's best action (Tap the Button labelled \"Profile\") had confidence 0.30, below the threshold." \
        "Session: $id"
    check "an unsure step acts on nothing" actions_are ""
    check "the session is kept" sessions_are 1
    [[ -n $id ]] || return 0
    check "the session file is readable only by the user" \
        test "$(stat -f %Lp "$case_dir/state/jev-sim-use/sessions/$id.json")" = 600
    check "the sessions directory is private" test "$(stat -f %Lp "$case_dir/state/jev-sim-use/sessions")" = 700

    jsu list session list
    check "session list shows the session and its goal" stdout_has list "$id"
    jsu show session show "$id"
    check "session show prints the goal, device, and run" stdout_is show "Session: $id (stopped)" \
        "Goal: Open the profile" "Device: E2E-DEVICE" "Notes:" "  (none)" "Runs:" \
        "$(sed -n 7p "$case_dir/show.stdout.txt")" "Actions:"
    check "the run line gives its time, actions, and outcome" grep -qE \
        "^  1\. [0-9T:-]+Z, 0 action\(s\): Stopped at step 1: " "$case_dir/show.stdout.txt"
    jsu tell session tell "$id" -n "The profile is the Profile row on the home screen."
    jsu tell2 session tell -n "A wrong fact."
    jsu forget session forget "$id" -n 2
    check "tell and forget leave the one right note" stdout_has forget "  1. The profile is the Profile row on the home screen."
    check "the wrong note is gone" negate stdout_has forget "A wrong fact."
    jsu nonote session forget "$id" -n 5
    check "forgetting a note the session does not have exits 2" status_is nonote 2
    check "and says how many there are" stderr_has nonote "No note 5: the session has 1."

    jsu resume session resume "$id" --base-url "$URL"
    check "the resumed run exits 0" status_is resume 0
    check "stderr says it resumes the session" stderr_has resume "Resuming session $id"
    check "the note reaches Jev" request_has 2 '.state.notes == ["The profile is the Profile row on the home screen."]'
    check "the resumed run taps the row" actions_are "tap @3  [no daemon]"
    check "the finished session is deleted" sessions_are 0
    jsu gone session show "$id"
    check "showing the deleted session exits 2" status_is gone 2
    common_run_checks
}

# --- Cases: guards against a false success or a loop --------------------------------------------------------------

case_unsure_done() {
    use_scenario unsure-done || return 1
    jsu run run "Show the summary" --base-url "$URL"
    check "exit status 1: a DONE below the bar is not success" status_is run 1
    check "stdout says probably reached" stdout_has run \
        "Stopped after 0 action(s): the goal is probably reached (p=0.50), but not surely; check the screen."
    check "nothing is done" actions_are ""
    common_run_checks
}

case_blocked() {
    use_scenario unsure-done '.answers = [{"op": "blocked", "p": 0.9}]' || return 1
    jsu run run "Show the summary" --base-url "$URL"
    check "exit status 1" status_is run 1
    check "BLOCKED hands over at once" stdout_has run \
        "Stopped at step 1: no offered action advances the goal on this screen."
    check "nothing is done" actions_are ""
    common_run_checks
}

case_no_effect_repeat() {
    use_scenario no-effect-repeat || return 1
    jsu run run "Refresh the feed" --base-url "$URL"
    check "exit status 1" status_is run 1
    check "a tap that changed nothing is not repeated" stdout_has run \
        "Stopped at step 2: no offered action advances the goal on this screen."
    check "the row is tapped once" actions_are "tap @3  [no daemon]"
    check "Jev learns the tap had no visible effect" request_has 2 '.state.history[0].result == "no visible effect"'
    common_run_checks
}

case_ticking_repeat() {
    use_scenario ticking-repeat || return 1
    jsu run run "Open the report" --base-url "$URL"
    check "exit status 1" status_is run 1
    check "a fourth identical tap on the same elements hands over" stdout_has run \
        "Stopped at step 4: no offered action advances the goal on this screen."
    check "the row is tapped three times although its relative time changed each time" actions_are \
        "tap @3  [no daemon]" "tap @3  [no daemon]" "tap @3  [no daemon]"
    common_run_checks
}

case_destructive_bar() {
    use_scenario destructive-bar || return 1
    jsu run run "Remove the item" --base-url "$URL"
    check "exit status 1" status_is run 1
    check "a destructive tap below 0.60 hands over" stdout_has run \
        "Stopped at step 1: Jev's best action (Tap the Button labelled \"Delete item\") had confidence 0.58"
    check "nothing is tapped" actions_are ""
    common_run_checks
}

case_app_disappears() {
    use_scenario app-disappears || return 1
    jsu run run "Play the track" --base-url "$URL"
    check "exit status 1" status_is run 1
    check "stdout names the app that disappeared" stdout_has run "Stopped: the app disappeared (com.example.sample)."
    check "Jev is not asked again" request_count_is 1
    common_run_checks
}

case_step_limit() {
    use_scenario step-limit || return 1
    jsu run run "Reach the last page" --max-steps 1 --base-url "$URL"
    check "exit status 1" status_is run 1
    check "stdout gives the limit" stdout_has run "Stopped: the step limit of 1 was reached."
    check "one action runs" actions_are "tap @3  [no daemon]"
    jsu resume session resume --max-steps 1 --base-url "$URL"
    check "a resumed run gets a fresh step budget" stdout_is resume "Goal reached after 1 action(s)."
    check "and numbers its steps after the earlier run's" stderr_has resume '[2] Tap the Button labelled "Next"'
    check "Jev sees the earlier run's history" request_has 3 '.state.history[0].step == 1'
    common_run_checks
}

case_hint_retry() {
    use_scenario hint-retry || return 1
    jsu run run "Ask the assistant to shorten the note" --base-url "$URL"
    check "exit status 0" status_is run 0
    check "stderr says it asks again with hints" stderr_has run "[1] unsure; asking again with the screen's accessibility hints"
    check "the first request leaves hints out" request_has 1 '[.state.screen.elements[] | has("hint")] | any | not'
    check "the retry carries the element's hint" request_has 2 \
        '.state.screen.elements[] | select(.label == "Assistant") | .hint == "Rewrites the note from an instruction"'
    check "the hinted plan acts" actions_are "tap @3  [no daemon]"
    common_run_checks
}

case_menu_backdrop() {
    use_scenario menu-backdrop || return 1
    jsu run run "Set the kind to option B" --base-url "$URL"
    check "exit status 0" status_is run 0
    check "the menu's dismiss backdrop is neither a target nor in the state" request_lacks 2 "Dismiss menu"
    check "no opener or menu rule before a menu shows" request_has 1 \
        '(.state.screen | has("opened_by") | not) and (.state.rules | contains("opened_by") | not)'
    check "the state names the control that opened the menu" request_has 2 \
        '(.state.screen.opened_by == "Kind, option A") and (.state.rules | contains("opened_by"))'
    check "the opener, then the item, are tapped" actions_are "tap @3  [no daemon]" "tap @5  [no daemon]"
    common_run_checks
}

# --- Cases: the other commands and failures -----------------------------------------------------------------------

case_doctor() {
    use_scenario tap-to-goal || return 1
    jsu ready doctor --base-url "$URL"
    check "a ready setup exits 0" status_is ready 0
    check "sim-use passes" stdout_has ready "✓ sim-use: 0.14.0 at $case_dir/bin/sim-use"
    check "the device passes after one screen read" stdout_has ready \
        "✓ device: E2E Phone (E2E-DEVICE); screen readable, 3 elements"
    check "jev passes" stdout_has ready "✓ jev: jev-1.13.0 at $URL/v1/systemone, API key set"
    check "doctor never calls Jev" request_count_is 0
    JSU_NO_KEY=1 jsu keyless doctor
    check "a missing key exits 1" status_is keyless 1
    check "the jev line says to set the key" stdout_has keyless "✗ jev: Set TYPESAFE_API_KEY"
    JSU_PATH=/usr/bin:/bin jsu missing doctor
    check "without sim-use the device check is skipped" stdout_has missing "– device: skipped, sim-use is not ready"
}

case_exec() {
    use_scenario tap-to-goal || return 1
    jsu devices exec devices --no-physical-ios --json
    check "exec passes sim-use's stdout through" stdout_has devices '"deviceId": "E2E-DEVICE"'
    check "exec exits with sim-use's status" status_is devices 0
    jsu bogus exec bogus-verb --flag
    check "a failing command's status passes through unchanged" status_is bogus 64
    check "the arguments reach sim-use as given" called_with bogus-verb --flag
    check "exec never calls Jev" request_count_is 0
}

# Whether the command under prefix `$2` printed the file `$1`, followed by the line break every output line gets.
printed() {
    diff <(cat "$1" && echo) "$case_dir/$2.stdout.txt"
}

# Whether `--help` (wrapped to the terminal width) contains `$1` once its lines are joined.
help_mentions() {
    tr '\n' ' ' <"$case_dir/help.stdout.txt" | tr -s ' ' | grep -qF -- "$1"
}

case_skill() {
    local file skills="$case_dir/home/.agents/skills/jev-sim-use"
    mkdir -p "$case_dir/home"
    jsu help --help
    check "root help points AI agents at the skill" help_mentions "\`jev-sim-use skill print\` prints it; \`jev-sim-use skill install --client claude|agents\`"
    jsu install skill install --client agents
    check "install reports where it wrote the skill" stdout_is install "Installed the skill at $skills"
    check "install writes SKILL.md" diff "$ROOT/skills/jev-sim-use/SKILL.md" "$skills/SKILL.md"
    check "install writes the references" diff -r "$ROOT/skills/jev-sim-use/references" "$skills/references"
    jsu again skill install --client agents
    check "installing over a skill without --force fails" negate status_is again 0
    check "and says to pass --force" stderr_has again "Pass --force to overwrite it."
    echo old >"$skills/references/retired.md"
    jsu force skill install --client agents --force
    check "a forced install succeeds" status_is force 0
    check "and removes files an older skill left" test ! -e "$skills/references/retired.md"
    jsu claude skill install --client claude
    check "the claude client installs under ~/.claude/skills" test -f "$case_dir/home/.claude/skills/jev-sim-use/SKILL.md"
    jsu uninstall skill uninstall --client agents
    check "uninstall reports the removed directory" stdout_is uninstall "Removed the skill from $skills"
    check "and removes it" test ! -e "$skills"
    jsu absent skill uninstall --client agents
    check "uninstalling again says nothing is installed" stdout_is absent "No skill installed at $skills"
    jsu main skill print
    check "skill print writes SKILL.md" printed "$ROOT/skills/jev-sim-use/SKILL.md" main
    for file in "$ROOT"/skills/jev-sim-use/references/*.md; do
        jsu "ref-$(basename "$file" .md)" skill print "references/$(basename "$file")"
        check "skill print references/$(basename "$file") writes that file" printed "$file" "ref-$(basename "$file" .md)"
    done
    jsu unknown skill print nope.md
    check "an unknown path exits 64" status_is unknown 64
    check "and lists the bundled files" stderr_has unknown "references/"
}

case_setup_errors() {
    use_scenario tap-to-goal || return 1
    JSU_NO_KEY=1 jsu keyless run "Open the details screen" --base-url "$URL"
    check "a missing key exits 2" status_is keyless 2
    check "and says to set it" stderr_has keyless "TYPESAFE_API_KEY"
    JSU_PATH=/usr/bin:/bin jsu missing run "Open the details screen" --base-url "$URL"
    check "a missing sim-use exits 2" status_is missing 2
    check "and gives the install command" stderr_has missing "brew install lycorp-jp/tap/sim-use"
    jsu flags run "Open the details screen" --actions tap,fly --base-url "$URL"
    check "an unknown --actions group exits 64" status_is flags 64
    check "no sim-use action and no request ran" actions_are ""
    check "no request was sent" request_count_is 0

    jsu nosession session resume --base-url "$URL"
    check "resuming with no sessions exits 2" status_is nosession 2
    check "and says how to start one" stderr_has nosession "No sessions yet."
    jsu unknown run "Open the details screen" -d E2E-MISSING --base-url "$URL"
    check "an unknown --device fails" negate status_is unknown 0
    check "it reads the full device list before giving up" called_with devices --json

    use_scenario tap-to-goal '.version = "v0.9.0"' || return 1
    jsu outdated run "Open the details screen" --base-url "$URL"
    check "an outdated sim-use exits 2" status_is outdated 2
    use_scenario tap-to-goal ".devices = [$SIMULATOR, $SIMULATOR + {deviceId: \"E2E-OTHER\"}]" || return 1
    jsu several run "Open the details screen" --base-url "$URL"
    check "two devices without --device exit 2" status_is several 2
    check "and list both" stderr_has several "E2E-OTHER"
    use_scenario tap-to-goal '.devices = []' || return 1
    jsu none run "Open the details screen" --base-url "$URL"
    check "no device exits 2" status_is none 2

    use_scenario tap-to-goal ".version = \"v0.15.0\"
        | .devices = [$SIMULATOR, $SIMULATOR + {deviceId: \"00008110-E2E\", kind: \"physical\"}]" || return 1
    jsu newer run "Open the details screen" --base-url "$URL"
    check "a newer sim-use still runs, on the only simulator beside a physical iPhone" status_is newer 0
    check "with a warning" stderr_has newer "Warning: sim-use 0.15.0 is newer than the tested 0.14.0."
}

case_runtime_errors() {
    use_scenario tap-to-goal '.screens.inbox.on["tap:Open details"] = {"error": "No snapshot", "hint": "Run ui first"}' \
        || return 1
    jsu failing run "Open the details screen" --base-url "$URL"
    check "a sim-use error envelope exits 3" status_is failing 3
    check "stderr gives sim-use's error and hint" stderr_has failing "failed: No snapshot"
    use_scenario tap-to-goal '.answers = [{"status": 422, "body": "state too long"}]' || return 1
    jsu rejected run "Open the details screen" --base-url "$URL"
    check "a 422 from Jev exits 3" status_is rejected 3
    check "stderr explains the rejection" stderr_has rejected "Jev rejected the request (422)"
}

# --- Driver --------------------------------------------------------------------------------------------------------

# Every case function must be listed in CASES, or it would silently never run.
for function in $(declare -F | sed -n 's/^declare -f case_//p'); do
    [[ " ${CASES[*]} " == *" ${function//_/-} "* ]] || fail_setup "case_$function is not listed in CASES."
done

# Runs one case in its own directory and writes its summary row there. Cases share nothing, so they run in parallel:
# most of their time is the binary waiting before a hand-over.
run_case() {
    local name=$1 started seconds total failures result=PASS
    case_dir="$OUT/$name"
    mkdir -p "$case_dir"
    : >"$case_dir/checks.txt"
    started=$(date +%s)
    "case_${name//-/_}" || echo "FAIL  setup: the case could not start" >>"$case_dir/checks.txt"
    stop_stub
    seconds=$(($(date +%s) - started))
    total=$(grep -c . "$case_dir/checks.txt")
    failures=$(grep '^FAIL' "$case_dir/checks.txt" | cut -c7- | paste -sd';' -)
    [[ -z $failures ]] || result=FAIL
    echo "| $name | $result | $total | $seconds | ${failures:--} |" >"$case_dir/summary-row.md"
}

# The first Python start on a fresh machine is slow; pay it once before the cases start theirs in parallel.
python3 -c pass
for name in "${selected[@]}"; do
    run_case "$name" &
done
wait

summary="$OUT/summary.md"
{
    echo "| Case | Result | Checks | Seconds | Failed checks |"
    echo "|---|---|---|---|---|"
} >"$summary"
for name in "${selected[@]}"; do
    echo "== $name" >&2
    sed 's/^/   /' "$OUT/$name/checks.txt" >&2
    cat "$OUT/$name/summary-row.md" >>"$summary"
done

echo
cat "$summary"
echo
echo "Artifacts: $OUT"
! grep -q '| FAIL |' "$summary"
