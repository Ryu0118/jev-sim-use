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
# shellcheck disable=SC2016 # jq programs name their argument `$a` inside single quotes.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/.build/release/jev-sim-use"
SETTINGS=com.apple.Preferences
GOALS=(route toggle scroll search hand-over already-met calendar maps photos reminders)
CALENDAR=com.apple.mobilecal
MAPS=com.apple.Maps
PHOTOS=com.apple.mobileslideshow
REMINDERS=com.apple.reminders

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
# Taps the switch `$1` until it reads `$2`: at most two taps, each followed by up to 3 s of readings. Under heavy host
# load one tap followed by a fixed 1 s wait left the switch as it was, while the goal's own flip had worked.
set_switch() {
    local id=$1 want=$2 x y
    for _ in 1 2; do
        [[ $(value_of "$id") == "$want" ]] && return 0
        read -r x y < <(ui_json | jq -r --arg a "$id" '[.data.entries[] | select(.uniqueId == $a)][0].frame
            | "\(.x + .width - 26) \(.y + .height / 2)"')
        SIM_USE_NO_DAEMON=1 sim-use tap -x "$x" -y "$y" --duration 0.05 --device "$DEVICE" --json >/dev/null
        for _ in 1 2 3 4 5 6; do
            sleep 0.5
            [[ $(value_of "$id") == "$want" ]] && return 0
        done
    done
    return 1
}

# Relaunches the app `$1` in English and waits until sim-use reads it as `$2`, past the screens a fresh simulator shows
# on an app's first launch. The launch arguments leave the simulator's own language as it is. Each further argument is
# a `simctl privacy` service granted first: a permission alert belongs to the system, shows in the simulator's own
# language, and stayed over every later app until answered, so it is granted rather than tapped away.
open_app() {
    local bundle=$1 name=$2 service
    for service in "${@:3}"; do
        xcrun simctl privacy "$DEVICE" grant "$service" "$bundle" || return 1
    done
    xcrun simctl terminate "$DEVICE" "$bundle" >/dev/null 2>&1
    xcrun simctl launch "$DEVICE" "$bundle" -AppleLanguages "(en)" -AppleLocale en_US >/dev/null || return 1
    for _ in $(seq 1 20); do
        [[ $(ui_json | jq -r '.data.appLabel // empty') == "$name" ]] && break
        sleep 0.5
    done
    dismiss_first_run
    [[ $(ui_json | jq -r '.data.appLabel // empty') == "$name" ]]
}

# Answers the screens an app shows on its first launch, which arrive a few seconds after it and one after another: a
# "What's New" sheet (Continue), an offer to sync or notify (Not Now), and system alerts that `simctl privacy` cannot
# grant, such as notifications, which are answered with their first button (Don't Allow) since their labels are in the
# simulator's language. Only this setup taps by label; it stops once two readings a second apart show none of them.
dismiss_first_run() {
    local quiet=0 screen point label
    for _ in $(seq 1 12); do
        screen=$(ui_json)
        if [[ $(jq -r '.data.appLabel // empty' <<<"$screen") == SpringBoard ]]; then
            point=$(jq -r '[.data.entries[] | select(.role == "Button")] | sort_by(.frame.y, .frame.x) | .[0].frame
                | select(. != null) | "\(.x + .width / 2) \(.y + .height / 2)"' <<<"$screen")
            [[ -n $point ]] && sim-use tap -x "${point% *}" -y "${point#* }" --device "$DEVICE" --json >/dev/null
            quiet=0
        elif label=$(jq -er '[.data.entries[] | select(.role == "Button" and (.label == "Continue" or .label == "Not Now"))]
            [0].label' <<<"$screen"); then
            sim-use tap --label "$label" --device "$DEVICE" --json >/dev/null
            quiet=0
        else
            quiet=$((quiet + 1))
            [[ $quiet -ge 2 ]] && return 0
        fi
        sleep 1
    done
}

# Taps the element with identifier `$1` when it shows.
tap_id_if_shown() {
    screen_has '.uniqueId == $a' "$1" || return 0
    sim-use tap --id "$1" --device "$DEVICE" --json >/dev/null
    sleep 1
}

# Relaunches Calendar in its list view, which lists events as rows whatever the time of day, scrolled to today. A
# relaunch may return it to the multi-day view, and the list keeps an earlier scroll position. Today's first event then
# sits under the bar, so the list is drawn down until it shows; the goals are about the event form, not reaching it.
open_calendar_list() {
    open_app "$CALENDAR" Calendar location || return 1
    if ! screen_has '.uniqueId == "toggle-day-list-view" and (.label | ascii_downcase) == $a' list; then
        sim-use tap --id toggle-day-list-view --device "$DEVICE" --json >/dev/null && sleep 1
        sim-use tap --id list-view --device "$DEVICE" --json >/dev/null && sleep 1
    fi
    tap_id_if_shown today-button
    sim-use swipe --from 200,300 --to 200,420 --duration 1 --device "$DEVICE" --json >/dev/null && sleep 1
    screen_has '.uniqueId == "toggle-day-list-view" and (.label | ascii_downcase) == $a' list
}

# Opens the event in the list whose label starts with `$1`, the first one below the bar that covers the list's top or
# the `$2`th after it (a later occurrence of a repeating event), and waits for its details.
open_calendar_event() {
    local point
    point=$(ui_json | jq -r --arg a "$1" --argjson n "${2:-0}" '[.data.entries[]
        | select(((.label // "") | startswith($a)) and .frame.y > 110)]
        | sort_by(.frame.y) | .[$n].frame | select(. != null) | "\(.x + .width / 2) \(.y + .height / 2)"')
    [[ -n $point ]] || return 1
    sim-use tap -x "${point% *}" -y "${point#* }" --device "$DEVICE" --json >/dev/null || return 1
    for _ in $(seq 1 10); do
        screen_has '.uniqueId == "alert-cell"' && return 0
        sleep 0.5
    done
    return 1
}

# Calendar's list view without any event an earlier run left behind.
open_calendar() {
    open_calendar_list || return 1
    delete_calendar_events || return 1
    open_calendar_list
}

# Deletes every event whose label starts with `E2E-`, with all its repeats. The earliest shown row is opened each time,
# below the bar that covers the list's top, so "all future events" takes the whole series; an occurrence edited on its
# own is a separate event and takes another pass.
delete_calendar_events() {
    local point
    for _ in 1 2 3 4 5; do
        point=$(ui_json | jq -r '[.data.entries[] | select(((.label // "") | startswith("E2E-")) and .frame.y > 110)]
            | sort_by(.frame.y) | .[0].frame | select(. != null) | "\(.x + .width / 2) \(.y + .height / 2)"')
        if [[ -z $point ]]; then
            # A row left under the bar cannot be tapped; drawing the list down brings it below.
            screen_has '(.label // "") | startswith("E2E-")' || break
            sim-use swipe --from 200,300 --to 200,420 --duration 1 --device "$DEVICE" --json >/dev/null
            sleep 1
            continue
        fi
        sim-use tap -x "${point% *}" -y "${point#* }" --device "$DEVICE" --json >/dev/null || return 1
        sleep 1.5
        tap_id_if_shown delete-event-cell
        tap_id_if_shown delete-event-button
        tap_id_if_shown delete-all-future-events-alert-button
        tap_id_if_shown delete-alert-button
        sleep 1
    done
    negate screen_has '(.label // "") | startswith("E2E-")'
}

# Relaunches Reminders on its default list. A relaunch may show the overview of lists instead, where the list is a row
# labelled with its name and count.
open_reminders_list() {
    local list
    open_app "$REMINDERS" Reminders || return 1
    list=$(ui_json | jq -r '[.data.entries[] | select(.role == "Button" and ((.label // "") | startswith("Reminders, ")))]
        [0].label // empty')
    [[ -n $list ]] || return 0
    sim-use tap --label "$list" --device "$DEVICE" --json >/dev/null || return 1
    wait_for_heading Reminders
}

# The Reminders list without any reminder an earlier run left behind (a long swipe deletes a row).
open_reminders() {
    open_reminders_list || return 1
    for _ in 1 2 3; do
        local frame
        frame=$(ui_json | jq -r '[.data.entries[] | select((.label // "") | startswith("E2E-"))][0].frame
            | select(. != null) | "\(.x + .width - 20),\(.y + .height / 2) \(.x + 40),\(.y + .height / 2)"')
        [[ -n $frame ]] || return 0
        sim-use swipe --from "${frame% *}" --to "${frame#* }" --duration 0.3 --device "$DEVICE" --json >/dev/null
        sleep 1.5
    done
    negate screen_has '(.label // "") | startswith("E2E-")'
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

# The actions the run `$1` took, one per line in its step-line wording ("Press Return", "Tap the Button labelled …"). A
# step's timing line follows its action, or ends the run for the last step, which took none; the plan just before
# each timing line is what ran, since a step may be planned more than once.
actions_taken() {
    perl -ne 'if (/\[(\d+)\] took /) { push @done, $plan{$1} } elsif (/\[(\d+)\] (.*?) \(support/) { $plan{$1} = $2 }
        END { pop @done; print "$_\n" for @done }' "$run_dir/$1.stderr.txt"
}

# Whether the run `$1` took an action matching the extended regex `$2`.
took_action() {
    actions_taken "$1" | grep -qE -- "$2"
}

# Whether the run `$1`'s actions, joined with " | ", match the extended regex `$2`; anchor it to match them whole.
actions_are() {
    [[ $(actions_taken "$1" | paste -sd'|' - | sed 's/|/ | /g') =~ $2 ]]
}

# Whether the back button names `$1`: the screen was reached from the screen with that title.
back_is() {
    screen_has '.uniqueId == "BackButton" and .label == $a' "$1"
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
    check "it was reached from Keyboard, the step before it" back_is Keyboards
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
    # Its last two actions: a Return pressed before typing is the placeholder limit described above.
    check "the query was typed, then Return pressed" actions_are run \
        '(Enter the query into .*|Replace the text in .* with the query) \| Press Return$'
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
    check "it is the About screen under General, as the note says" back_is General
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

# Creating an event with a typed title and two menus (one behind the date row), then reopening and editing it.
goal_calendar() {
    local title=E2E-Standup
    open_calendar || return 1
    jsu run "Create a new event titled with the title text, set its Alert to 15 minutes before, open its date and \
time to set Repeat to Every Week, then save it; the goal is reached when the event shows in the list" \
        -t title="$title" -d "$DEVICE" --max-steps 12
    check "exit status 0" status_is run 0
    check "the list shows the event" screen_has '(.label // "") | startswith($a)' "$title"
    # The second run changes the alert, so the first run's alert and repeat are read here, by opening the event
    # without Jev.
    if open_calendar_event "$title"; then
        check "the event's details show the alert asked for" screen_has '.uniqueId == "alert-cell" and .label == $a' \
            "Alert, 15 minutes before"
        check "the event repeats weekly" screen_has '.uniqueId == "event-details-recurrence-button"
            and ((.label // "") | test("weekly"; "i"))'
    else
        check "the event opens from the list" false
    fi
    open_calendar_list || return 1
    jsu run2 "Open the event titled with the title text and change its alert to 5 minutes before, then save it for \
future events" -t title="$title" -d "$DEVICE" --max-steps 8
    check "the edit exits 0" status_is run2 0
    check "the event's details show the new alert" screen_has '.uniqueId == "alert-cell" and .label == $a' \
        "Alert, 5 minutes before"
    check "the event still repeats weekly" screen_has '.uniqueId == "event-details-recurrence-button"
        and ((.label // "") | test("weekly"; "i"))'
    # Saved for future events, the next week's occurrence has the new alert too; saved for this event only, it would
    # keep the old one.
    if open_calendar_list && open_calendar_event "$title" 1; then
        check "the next occurrence shows the new alert too" screen_has '.uniqueId == "alert-cell" and .label == $a' \
            "Alert, 5 minutes before"
    else
        check "the next occurrence opens from the list" false
    fi
    check "the event is deleted afterwards" open_calendar
}

# Searching Maps with a typed place and opening it with Return. Needs the network.
goal_maps() {
    open_app "$MAPS" Maps location || return 1
    tap_id_if_shown CardButtonTypeClose
    jsu run "Search for the place in the Maps search field, then press Return" -t place="Golden Gate Bridge" \
        -d "$DEVICE" --max-steps 6 --actions tap,type,return
    check "exit status 0" status_is run 0
    check "the place card for the place shows" screen_has '.uniqueId == "PlaceHeaderView"
        and ((.label // "") | startswith("Golden Gate Bridge"))'
    check "the place was typed, then Return pressed" actions_are run \
        '^(Enter the place into .*|Replace the text in .* with the place) \| Press Return$'
    tap_id_if_shown CardButtonTypeClose
}

# Opening a photo from the library grid and going back to it.
goal_photos() {
    open_app "$PHOTOS" Photos || return 1
    tap_id_if_shown LibraryTab
    jsu run "Open the first photo in the library, then go back to the library" -d "$DEVICE" --max-steps 6
    check "exit status 0" status_is run 0
    check "two actions ran: opening the photo and going back" stdout_has run "after 2 action(s)."
    # Every cell is labelled "Photo", so which photo opened cannot be told from the log; that it was a photo can.
    check "a photo was opened, then the run went back" actions_are run '^Tap the Image labelled "Photo" \| Go back$'
    check "the library grid shows again" screen_has '.uniqueId == "LibraryTab" and (.states | index("selected"))'
}

# Adding a reminder with a typed title, then deleting it with its swipe action.
goal_reminders() {
    local title=E2E-Task
    open_reminders || return 1
    jsu run "Add the title text to this list as a new reminder" -t title="$title" -d "$DEVICE" --max-steps 5
    check "exit status 0" status_is run 0
    check "the list shows the reminder" screen_has '(.label // "") | startswith($a)' "$title"
    open_reminders_list || return 1
    jsu run2 "Delete the reminder titled with the title text using its swipe actions; the goal is reached once it no \
longer shows" -t title="$title" \
        -d "$DEVICE" --max-steps 5 --actions tap,swipe
    check "the deletion exits 0" status_is run2 0
    check "the reminder is gone" negate screen_has '(.label // "") | startswith($a)' "$title"
    check "the deletion used a swipe action" took_action run2 '^Swipe'
    check "no reminder is left behind" open_reminders
}

# Stops the recording `$1` without ever blocking the suite: SIGINT makes simctl write the file, and the suite once
# waited 26 minutes on a recorder that had inherited an ignored SIGINT. If it is still running 10 s after SIGINT, it is
# killed and the goal's checks note it: the file may be truncated, and a recorder that did not stop on SIGINT left the
# simulator's recording busy ("Host recording is already in progress") until the simulator rebooted, so later goals
# may go unrecorded (a recorder that cannot start exits at once). SIGTERM is no gentler: it wrote an empty file.
stop_recorder() {
    local pid=$1
    kill -INT "$pid" 2>/dev/null
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || {
            wait "$pid" 2>/dev/null
            return 0
        }
        sleep 0.5
    done
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    echo "NOTE  the recording may be truncated: the recorder ignored SIGINT for 10 s and was killed" >>"$run_dir/checks.txt"
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

        # A non-interactive shell starts background jobs with SIGINT ignored; restoring it lets SIGINT finish the file.
        (
            trap - INT
            exec xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$run_dir/recording.mp4" >/dev/null 2>&1
        ) &
        recorder=$!
        started=$(date +%s)
        "goal_${name//-/_}" || echo "FAIL  setup: could not reach the starting screen" >>"$run_dir/checks.txt"
        wall=$(($(date +%s) - started))
        stop_recorder "$recorder"

        for prefix in run run2 resume; do
            [[ -f $run_dir/$prefix.stdout.txt ]] || continue
            session=$(session_of "$prefix")
            if [[ -n $session ]] && session_exists "$session"; then
                "$BIN" session show "$session" >"$run_dir/session-show.txt"
            fi
        done
        ui_json >"$run_dir/ui.json" 2>&1
        sim-use ui --device "$DEVICE" >"$run_dir/ui.txt" 2>&1

        exits=$(cat "$run_dir"/{run,run2,resume}.exit-status 2>/dev/null | paste -sd/ -)
        actions=$(cat "$run_dir"/{run,run2,resume}.stdout.txt 2>/dev/null \
            | sed -nE 's/.*(after|at step) ([0-9]+).*/\2/p' | paste -sd/ -)
        steps=$(cat "$run_dir"/{run,run2,resume}.stderr.txt 2>/dev/null \
            | sed -nE 's/^ *([0-9.]+)  \[([0-9]+)\] .*\(support.*/\2@\1/p' | paste -sd' ' -)
        cost=$(cat "$run_dir"/{run,run2,resume}.stderr.txt 2>/dev/null \
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
