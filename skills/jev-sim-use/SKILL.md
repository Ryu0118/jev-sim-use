---
name: jev-sim-use
description: Reach a screen in an iOS Simulator or Android device with one command instead of driving sim-use tap by tap. Use when an agent needs to navigate an app to some state ("open Settings > Display", "get to the search results for ramen", "turn on Dark Mode") before checking or testing something there. jev-sim-use hands each step to Jev, a fast typed-judgment model, so navigation costs one shell call rather than one reasoning turn per tap. Also runs any sim-use command through `jev-sim-use exec`.
---

# jev-sim-use

Delegate navigation, keep your turns for the real work. Instead of reading the UI, choosing a tap, and repeating,
run one command with the goal. jev-sim-use observes the screen with sim-use, asks Jev which on-screen action comes next,
acts, and repeats until Jev judges the goal reached or it has to stop.

## When to use

- Use `jev-sim-use "<goal>"` to get somewhere: a screen, a toggle state, a search result.
- Use `jev-sim-use exec <sim-use args>` for precise, single steps and for checking the result:
  `exec ui` to read the screen, `exec screenshot` to capture it, `exec tap ...` for one exact tap.
- Do not use it to verify a result. It stops when Jev believes the goal is reached; confirm with `exec ui` when it matters.

## Before the first run

```sh
jev-sim-use doctor        # sim-use installed, one usable device, TYPESAFE_API_KEY set
```

The app must already be open; sim-use cannot launch apps. The API key comes only from `TYPESAFE_API_KEY`.

## Running

```sh
jev-sim-use "Turn on Dark Mode in Settings"
jev-sim-use "Search for ramen" -t ramen            # -t: text it may paste; repeat for several
jev-sim-use exec devices                           # list deviceIds when several are booted
jev-sim-use "Open Wi-Fi settings" -d <deviceId>
```

- Write the goal as the end state you want, specific enough to recognize ("Wi-Fi settings screen is open").
- Jev never writes text. If the goal needs typing, pass every string with `-t`, or it cannot finish.
- stdout is the outcome line, then `Session: <id>`; stderr is step-by-step progress. Every run is saved as a session
  under `$XDG_STATE_HOME/jev-sim-use/sessions` (default `~/.local/state`).

## Results

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Goal reached | Verify with `exec ui` if the next step depends on it |
| 1 | Stopped before the goal | Read the stdout line (below), then supervise the session |
| 2 | Setup problem | Run `jev-sim-use doctor` and fix what it reports |
| 3 | sim-use or Jev failed mid-run | Retry once; if it repeats, read the error |

Stop reasons on exit 1:

- **confidence below the threshold**: Jev was unsure which action is next. Low confidence is a handover signal, not a
  crash: `tell` what it is missing and `resume`.
- **no offered action advances the goal**: Jev does not know where the target lives. `tell` where it is and `resume`,
  or navigate closer yourself with `exec`, then `resume`.
- **the screen stopped changing**: taps are not landing. Inspect with `exec ui` / `exec screenshot` before resuming.
- **step limit reached**: `resume` gives it another `--max-steps` actions.
- **app crashed or disappeared**: relaunch the app; do not resume blindly.

## Supervising a session

Every run is a session. When it stops short, you are the supervisor: look, add what Jev cannot know, and continue.
Do not start a new run with a longer goal; the session keeps the goal, the history, and your notes.

```sh
jev-sim-use session show                  # goal, notes, how each run ended, every action taken
jev-sim-use exec ui                       # the screen it stopped on
jev-sim-use session tell -n "Dark Mode is the Dark Appearance switch under Developer"
jev-sim-use session tell -n "The goal is reached when the Dark Appearance switch is on"
jev-sim-use session resume                # same goal, with the notes and history; exits like a run
```

- Notes are facts about the app, not tap-by-tap instructions: where a setting lives, what a label means, what the
  finished screen looks like. Jev reads them when choosing each action and when judging whether the goal is reached.
- Jev picks visible targets well but does not know where an off-screen setting lives, and judges toggle goals poorly.
  Those are the notes worth adding.
- You may act with `exec` between runs (for example to open the right app); `resume` starts from the current screen.
- Commands take a session id; without one they use the most recent session. `session list` shows them all.

## Options

| Option | Default | Use |
|---|---|---|
| `-t, --text` | none | Text it may paste into fields |
| `-d, --device` | the only usable device | A `deviceId` from `exec devices` |
| `--max-steps` | 15 | Upper bound on actions in this run; `session resume` gets a fresh budget |
| `--min-confidence` | 0.6 | Lower it to hand over less often, raise it to be more careful |

## Privacy

Each step sends the screen's visible labels and values, the goal, the action history, the session notes, and every
`-t` value to the Jev endpoint. Sessions are saved locally with the goal, texts, notes, and actions. Do not run it on screens with data that may not leave the machine.
