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
- sim-use itself for reading the screen, checking a result, single exact actions, and anything Jev is not offered.
  Run it through `jev-sim-use exec <sim-use args>` to target the same device. Learn its commands from sim-use's own
  skill and `sim-use --help`; [references/sim-use.md](references/sim-use.md) says how to install that skill
  (without this skill installed, read it with `jev-sim-use skill print references/sim-use.md`).

## Before the first run

```sh
jev-sim-use doctor     # sim-use installed, one usable device, TYPESAFE_API_KEY set
```

- Open the app yourself; sim-use cannot launch apps. Give it a few seconds, then dismiss any late prompt (rating
  request, tracking, notifications, password save). These appear after launch and derail a run midway.
- When several devices are booted, pass `--device <deviceId>` to every command, including `exec`, so every step
  and every check hits the same device.
- Give the simulator what the app needs from the device. An app that records location or motion does nothing
  useful on a simulator with no location set; set one (and a moving route when the task needs movement) with
  `xcrun simctl location`, as its `--help` describes.
- Typing pastes through the simulator's hardware keyboard. Without one connected, the run stops with a setup error
  (exit 2) instead of silently typing nothing.

## Choose the goal's form: an end state or numbered steps

The goal is the only thing Jev knows about your intent. Jev does not know the app, so every screen it has to find
on its own is a place where it can guess wrong or hand over. Choose the form by how much of the route Jev would
have to discover:

- **An end state** for short goals: one to three actions, where the target is on the current screen or one obvious
  hop away. Describe the finished state in the app's own terms.
- **Numbered steps** for anything longer: several screens, a flow that returns somewhere and continues, or a screen
  with two features that look alike. Spell out the route, one action per step. In a comparison run, a
  create-edit-favourite-convert-complete flow written as an end state stalled at its fourth action and once left the
  app; the same flow written as numbered steps, with its taps named by their on-screen text, ran 16 actions in about
  32 seconds, most of them at 0.9 support or higher.

<examples>
<example>
jev-sim-use "Turn on Dark Mode in Settings"
</example>
<example>
jev-sim-use "Search the memos for the query text and show the results" -t query=milk
</example>
<example>
jev-sim-use --max-steps 30 --actions tap,type,scroll,back,wait "1. On the Home tab, tap the New Memo button.
2. In the editor, enter the title text into the Title field.
3. Tap Save.
4. In the memo list, tap the memo Buy milk.
5. On the memo's screen, tap Favorite.
6. Tap Type and choose To-do.
7. Tap Back until the Home tab shows the memo list.
The goal is reached when the memo shows as a favorite to-do in the Home tab's list." -t title="Buy milk"
</example>
<example>
jev-sim-use "1. Tap the Profile tab.
2. Tap Account, then Sign In.
3. Enter the email into the Email field and the password into the Password field.
4. Tap Sign In.
The goal is reached when the Profile tab shows the signed-in email." -t email=alice@example.com -t password=hunter2
</example>
</examples>

How to write numbered steps so Jev follows them:

- Read the screens first (with sim-use through `exec`) and use each control's label exactly as the screen shows it.
  Jev matches steps against those labels, so "tap Favorite" beats "mark it as a favourite" when the button says
  Favorite.
- Say which screen each step happens on ("On the Home tab", "In the editor"). That keeps Jev from acting on a
  look-alike control on the wrong screen.
- Refer to controls by their labels, never by coordinates or positions; Jev only sees labels.
- Make an explicit save or submit tap its own step when the app has one. Controls can appear only after a change
  (a sheet shows Save once a field is edited), so scout a step with its change made, not just by opening the screen.
- Write a step plainly even when the app is slow to show its result (a saved item reaching its list). The run keeps
  reading for up to 5 s before it hands over, and Jev waits on a loading screen by itself. Spelling it out ("wait
  until the memo appears, then tap it") split Jev between waiting and tapping and left it at 0.3-0.5.
- Pass `--actions` with the operation groups the route uses (`tap,type,scroll,back,wait` for most form and
  navigation flows). Each request gets shorter, and gestures or hardware buttons the route never needs cannot be
  chosen by mistake.
- End with the finished state as a sentence Jev can check on screen, and one that is not already true where the run
  starts: a route that ended on the tab it started from was judged done before its first step. Exit 0 is still a
  claim; read the screen.
- Name what to tap by the text on screen ("tap the memo Pick up the parcel"); keep `-t` for text to type. A step that
  pointed at "the memo titled with the title text" left Jev at 0.3-0.5, the same step with the title written out at
  0.92.
- Give the run room: allow about two actions per numbered step with `--max-steps` (the default is 15).

These apply to both forms:

- Pass every string to type as `-t name=value`. Jev never writes text; it sees only the name and picks the field whose
  label fits, so name strings by what they are (`email`, `password`, `query`, `title`). Values never leave the
  machine.
- When the goal creates something through a form with a save or submit button, say "and save it" (or give Save its
  own step). Typed text in an open form is not saved, and Jev does not count it as done. When the app saves by itself
  (stopping a recording, toggling a setting), describe the finished state instead ("the recording is stopped and
  listed in history"); a "save" step that does not exist leaves Jev looking for one and handing over.
- Name the feature when two look alike ("edit it yourself" versus "ask the AI assistant"). An AI feature may
  otherwise receive your text as an instruction.
- Place words such as "home", "settings", "search", and "back" mean the app's own tab, screen, or button first; the
  device's only when the app has none. Say "the device's Home Screen" if you do mean to leave the app, and expect a
  hand-over: leaving the app needs high confidence because sim-use cannot open it again.
- When a long flow still stops, verify the screen it stopped on, `tell` what is missing, and `resume`. When the flow
  has natural checkpoints you want to verify anyway (a record that must exist before it can be analysed), run each
  part as its own goal.

## Read the result, then verify it

stdout is the outcome line; stderr shows each step. When the goal was not reached, `Session: <id>` follows.

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Goal reached | Read the screen and verify before relying on it |
| 1 | Stopped before the goal | Read the reason below, then supervise the session |
| 2 | Setup problem | Run `jev-sim-use doctor` and fix what it reports |
| 3 | sim-use or Jev failed mid-run | Read the screen first (the failed step may have scrolled or moved it), then retry once; if it repeats, read the error |

Exit 0 is Jev's judgment, not proof. Read the screen once the app has settled: a saved item can take a second or two
to show up in a list, so read, wait about two seconds, and judge the second reading.

Stop reasons on exit 1:

- **confidence below the threshold**: Jev was unsure what to do next and handed over instead of guessing. The step
  line shows which answer was weak, such as `support 0.49 [operation 0.97, element 0.49]`: here, what to act on.
- **no offered action advances the goal**: Jev does not know where the target lives. `tell` where it is, or get
  closer with `exec`, then `resume`.
- **the screen stopped changing**: actions are not landing. Read the screen and look at it before resuming.
- **the goal is probably reached, but not surely**: read the screen; if it is not done, `tell` what the finished
  screen looks like and `resume`.
- **step limit reached**: `resume` gives another `--max-steps` actions.
- **app crashed or disappeared**: relaunch the app before resuming.

When a stop is not obvious, read [references/troubleshooting.md](references/troubleshooting.md) (or
`jev-sim-use skill print references/troubleshooting.md`): it maps the usual causes (rows exposed as loose text,
look-alike buttons, unlabelled sliders, prompts sim-use cannot see, hidden controls, slow submits) to the note or fix
that resolves each, and lists what to rule out before blaming the run.

## Supervise the session instead of starting over

Every run is a session that keeps the goal, the history, and your notes. When it stops short, look, add what Jev
cannot know, and continue; a fresh run with a longer goal loses all of that.

```sh
jev-sim-use session show                  # goal, notes, how each run ended, every action taken
jev-sim-use session tell -n "Dark Mode is the Dark Appearance switch under Developer"
jev-sim-use session tell -n "The goal is reached when the Dark Appearance switch is on"
jev-sim-use session forget -n 1           # drop note 1 (as `show` numbers them) if it proved wrong
jev-sim-use session resume                # same goal, notes, and history; exits like a run
```

- Write notes as facts about the app: where a setting lives, what a label means, what the finished screen looks
  like. Jev reads every note for every action, so a tap instruction in a note keeps pulling it back to that tap
  after it is done. The route belongs in the goal's numbered steps; notes supply the facts the steps rely on.
- Remove a wrong note with `forget`; a correction added on top still leaves the wrong fact in front of Jev.
- Look at the screen it stopped on (read it with sim-use through `exec`) before adding a note.
- Prefer `tell` and `resume` to acting by hand, so the session keeps a record of what worked. Act by hand with sim-use
  through `exec` for what Jev is not offered or what fails the same way twice (see "Before blaming the run" in
  [references/troubleshooting.md](references/troubleshooting.md)); `resume` starts from whatever screen is showing.
- Add the missing fact rather than lowering `--min-confidence`. A lowered bar once let a run leave the app and report
  success in another one; a hand-over only costs a note.
- Commands take a session id; without one they use the most recent session. `session list` shows them all.

Sessions live under `$XDG_STATE_HOME/jev-sim-use/sessions` (default `~/.local/state`). Reaching the goal deletes the
session; an unfinished one expires a week after it last changed.

## What Jev can do

Taps; long-press, swipes, pinch, and rotate on an element; scrolls in four directions; going back where the screen
has a back button (iOS) or always (Android); a right-edge swipe; Return, to submit a search or form; and hardware
buttons; and waiting a moment while the app loads or a saved item has not reached its list yet. A tap Jev judges
irreversible (deleting or discarding something, in any language) needs at least 0.6 confidence and a hardware button
(leaving the app) 0.85, because going back cannot undo them. Anything else sim-use can do is left to you through
`exec`.

## Options

| Option | Default | Use |
|---|---|---|
| `-t, --text` | none | `name=value` to enter into a field; Jev sees only the name |
| `-d, --device` | the only usable device | A sim-use device id (list them with sim-use through `exec`) |
| `--max-steps` | 15 | Upper bound on actions in this run; `session resume` gets a fresh budget |
| `--min-confidence` | 0.55 | Lower it to hand over less often, raise it to be more careful |
| `--actions` | all | Comma-separated operation groups Jev may choose from (`tap`, `type`, `scroll`, `back`, `return`, `long-press`, `swipe`, `pinch`, `rotate`, `buttons`, `wait`). Naming only what the goal needs, such as `tap,type,scroll,back,wait` for form and navigation flows, shortens every request and rules out wrong gestures and hardware buttons |

## Privacy

Each step sends the screen's visible labels and values, the goal, the action history, the session notes, and the
names of the `-t` texts to the Jev endpoint; `-t` values never leave the machine. Unfinished sessions are kept
locally for up to a week, readable only by the user, with the goal, texts, notes, and actions. Do not run it on
screens with data that may not leave the machine.

## More

Without this skill installed, print a reference with `jev-sim-use skill print references/<file>.md`.

- [references/sim-use.md](references/sim-use.md): install sim-use's own skill; read before using sim-use directly.
- [references/troubleshooting.md](references/troubleshooting.md): read when a run stops and the reason is not obvious,
  or before planning a long flow on an unfamiliar app.
