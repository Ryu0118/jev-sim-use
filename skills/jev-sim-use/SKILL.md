---
name: jev-sim-use
description: Reach a screen, setting, or filled-in form in an iOS Simulator or Android app with one command instead of driving sim-use tap by tap. Use it whenever an agent needs to navigate an app to some state before checking or testing something there ("open Settings > Display", "search for ramen and show the results", "sign in with this email", "create a memo and save it"), even if the user only says "go to", "open", or "get to". jev-sim-use hands each step to Jev, a fast typed-judgment model, so navigation costs one shell call rather than one reasoning turn per tap. Also runs any sim-use command through `jev-sim-use exec`.
---

# jev-sim-use

Delegate navigation and keep your own turns for the real work. You give one goal; jev-sim-use reads the screen with
sim-use, asks Jev which on-screen action comes next, acts, and repeats until Jev judges the goal reached or has to
stop. Jev is fast and good at picking a visible target. It does not know your app, cannot write text, and can be
wrong about being done, so your part is to give it an unambiguous goal, check the end state, and fill in facts when
it stops.

## When to use it

- `jev-sim-use "<goal>"` to get somewhere in several steps: a screen, a toggle state, a submitted search, a saved
  item.
- `jev-sim-use exec <sim-use args>` for single exact steps and for checking results: `exec ui` to read the screen,
  `exec screenshot` to see it, `exec tap @N` for one tap.
- sim-use directly, through its own skill, for what jev-sim-use does not offer (double tap, `type`, key presses,
  multi-touch, video). See [references/sim-use.md](references/sim-use.md) for installing that skill and choosing
  between the two.

## Before the first run

```sh
jev-sim-use doctor     # sim-use installed, one usable device, TYPESAFE_API_KEY set
```

- Open the app yourself; sim-use cannot launch apps. Give it a few seconds, then dismiss any late prompt (rating
  request, tracking, notifications, password save). These appear after launch and derail a run midway.
- When several devices are booted, pass `--device <deviceId>` to every command, including `exec`; aliases like `@12`
  belong to the last screen read of one device.
- Typing pastes through the simulator's hardware keyboard. Without one connected, the run stops with a setup error
  (exit 2) instead of silently typing nothing.

## Write the goal as an unambiguous end state

The goal is the only thing Jev knows about your intent, and wrong successes almost always came from a goal that
allowed two readings. Write the finished state in the app's own terms:

```sh
jev-sim-use "Turn on Dark Mode in Settings"
jev-sim-use "Search the memos for the query text and show the results" -t query=milk
jev-sim-use "Create a memo whose title is the title text and save it" -t title="Buy milk"
jev-sim-use "Sign in with the email and the password" -t email=alice@example.com -t password=hunter2
jev-sim-use "Go back to the app's Home tab"
```

- Pass every string to type as `-t name=value`. Jev never writes text; it sees only the name and picks the field whose
  label fits, so name strings by what they are (`email`, `password`, `query`, `title`). Values never leave the
  machine. After typing, elements that show a text carry its name, so "the memo titled with title" is findable.
- Say "and save it" (or submit, send) when the goal creates something. Typed text in an open form is not saved, and
  Jev does not count it as done.
- Name the feature when two look alike ("edit it yourself" versus "ask the AI assistant"). An AI feature may
  otherwise receive your text as an instruction.
- Place words such as "home", "settings", "search", and "back" mean the app's own tab, screen, or button first; the
  device's only when the app has none. Say "the device's Home Screen" if you do mean to leave the app, and expect a
  hand-over: leaving the app needs high confidence because sim-use cannot open it again.
- Split long flows into several goals and check each end state. Uncertainty compounds, so a five-part goal fails far
  more often than five short ones. Continue from where the last one stopped.

## Read the result, then verify it

stdout is the outcome line; stderr shows each step. When the goal was not reached, `Session: <id>` follows.

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Goal reached | Verify with `exec ui` before relying on it |
| 1 | Stopped before the goal | Read the reason below, then supervise the session |
| 2 | Setup problem | Run `jev-sim-use doctor` and fix what it reports |
| 3 | sim-use or Jev failed mid-run | Retry once; if it repeats, read the error |

Exit 0 is Jev's judgment, not proof. Read the screen once the app has settled: a saved item can take a second or two
to show up in a list, so read, wait about two seconds, and judge the second reading.

Stop reasons on exit 1:

- **confidence below the threshold**: Jev was unsure what to do next and handed over instead of guessing. The step
  line shows which answer was weak, such as `support 0.49 [operation 0.97, element 0.49]`: here, what to act on.
- **no offered action advances the goal**: Jev does not know where the target lives. `tell` where it is, or get
  closer with `exec`, then `resume`.
- **the screen stopped changing**: actions are not landing. Inspect with `exec ui` / `exec screenshot`.
- **the goal is probably reached, but not surely**: check with `exec ui`; if it is not done, `tell` what the finished
  screen looks like and `resume`.
- **step limit reached**: `resume` gives another `--max-steps` actions.
- **app crashed or disappeared**: relaunch the app before resuming.

When a stop is not obvious, read [references/troubleshooting.md](references/troubleshooting.md): it maps the usual
causes (rows exposed as loose text, look-alike buttons, unlabelled sliders, prompts sim-use cannot see, slow
submits) to the note or fix that resolves each.

## Supervise the session instead of starting over

Every run is a session that keeps the goal, the history, and your notes. When it stops short, look, add what Jev
cannot know, and continue; a fresh run with a longer goal loses all of that.

```sh
jev-sim-use session show                  # goal, notes, how each run ended, every action taken
jev-sim-use exec ui                       # the screen it stopped on
jev-sim-use session tell -n "Dark Mode is the Dark Appearance switch under Developer"
jev-sim-use session tell -n "The goal is reached when the Dark Appearance switch is on"
jev-sim-use session forget -n 1           # drop note 1 (as `show` numbers them) if it proved wrong
jev-sim-use session resume                # same goal, notes, and history; exits like a run
```

- Write notes as facts about the app, not tap-by-tap instructions: where a setting lives, what a label means, what the
  finished screen looks like. Jev reads them for every action and for judging the goal.
- Remove a wrong note with `forget`; a correction added on top still leaves the wrong fact in front of Jev.
- Fix things by hand between runs when that is quicker (`exec`, or sim-use through its skill); `resume` starts from
  whatever screen is showing.
- Add the missing fact rather than lowering `--min-confidence`. A lowered bar once let a run leave the app and report
  success in another one; a hand-over only costs a note.
- Commands take a session id; without one they use the most recent session. `session list` shows them all.

Sessions live under `$XDG_STATE_HOME/jev-sim-use/sessions` (default `~/.local/state`). Reaching the goal deletes the
session; an unfinished one expires a week after it last changed.

## What Jev can do

Taps; long-press, swipes, pinch, and rotate on an element; scrolls in four directions; going back where the screen
has a back button (iOS) or always (Android); a right-edge swipe; Return, to submit a search or form; and hardware
buttons. Tapping a Delete control needs at least 0.6 confidence and a hardware button (leaving the app) 0.85,
because going back cannot undo them. Double tap, `type`, and raw coordinates are not offered; use `exec` or sim-use.

## Options

| Option | Default | Use |
|---|---|---|
| `-t, --text` | none | `name=value` to enter into a field; Jev sees only the name |
| `-d, --device` | the only usable device | A `deviceId` from `exec devices` |
| `--max-steps` | 15 | Upper bound on actions in this run; `session resume` gets a fresh budget |
| `--min-confidence` | 0.55 | Lower it to hand over less often, raise it to be more careful |

## Privacy

Each step sends the screen's visible labels and values, the goal, the action history, the session notes, and the
names of the `-t` texts to the Jev endpoint; `-t` values never leave the machine. Unfinished sessions are kept
locally for up to a week, readable only by the user, with the goal, texts, notes, and actions. Do not run it on
screens with data that may not leave the machine.

## More

- [references/sim-use.md](references/sim-use.md): install the sim-use skill and when to use sim-use directly.
- [references/troubleshooting.md](references/troubleshooting.md): read when a run stops and the reason is not obvious.
- [references/lessons.md](references/lessons.md): what driving real apps taught about goals, verification, and app
  accessibility; read before planning a long or unfamiliar flow.
