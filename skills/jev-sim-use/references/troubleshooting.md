# When a run stops: reading the cause

Start from the step lines on stderr. Each shows the chosen action and its support, broken down by the answers it
depends on, for example `support 0.49 [operation 0.97, element 0.49]`. The lowest number names what Jev was unsure
about: the operation (what to do), the element (what to act on), the field, or the text. That tells you what a note
or a fix has to supply.

## Causes seen most often

**Low `element` on a row Jev clearly meant.** The row's title, its chevron, and its timestamp each get 0.4-0.55.
The app exposes the row as separate text and image pieces instead of one button (typically a SwiftUI
`onTapGesture` on a stack), so Jev splits its choice among them. `tell` which row opens the item, or tap it with
`exec`. The lasting fix is in the app: give tappable rows and cells `.accessibilityElement(children: .combine)` (or
`.ignore` with a label) and `.accessibilityAddTraits(.isButton)`.

**Jev picks a real button (an Add menu) over the item you meant.** The item has no button trait, so it reads as
plain text while the menu reads as an action. Same fix as above. If the item is already a button, the goal's wording
is steering Jev: "post a record for X" can read as "add", so name the item you want opened.

**Two controls whose labels look alike** (an AI rewrite and a plain Edit). Jev may take the wrong one, and an AI
feature may receive your text as an instruction. Make the labels distinct in the app, and give each an
`accessibilityHint` that says what it does. When Jev would otherwise hand over, jev-sim-use asks once more with the
screen's hints ("asking again with the screen's accessibility hints" in the step lines).

**A slider labelled with a number.** The slider has no accessibility label, so its label is its raw position.
jev-sim-use names it from the text above it, but sim-use drags do not move SwiftUI sliders; set it by hand. App fix:
`Slider(...) { Text("…") }` plus an `.accessibilityValue` with the displayed value and unit.

**Something visible that the screen reading does not list.** A system prompt from another process (a password-save
alert), most cells of a colour grid, a popover's close button. Take a screenshot with sim-use and act on it by
coordinates, as its skill describes.

**An element that is listed but does nothing when tapped.** Some apps hide a control visually while keeping it in the
accessibility tree (a floating button that hides while its list is scrolled). Take a screenshot with sim-use to see
what is really on screen, bring the control back (scroll the list to the top), and resume. Switches and value rows
(colour wells, pickers) need no help: jev-sim-use taps their trailing control with the short hold they require.

**Search.** A search field that acts on Return is fine; Jev can press Return. A results screen without a heading
often ends as "probably reached"; read the screen to confirm.

**Slow submits.** After an action the run keeps reading for up to 2 s while the screen has not changed, and before
handing over it waits up to 5 s more for the screen to move on. It does not repeat an action that changed nothing on
the same screen, but a submit that only shows a spinner has changed the screen; if the stop reason mentions the
submit screen, check whether it went through before resuming.

**Interruptions.** Rating requests, tracking prompts, notification permission, password-save alerts, and promo
banners can appear seconds after launch and derail a run midway. Clear them before starting, and after launching
an app give it a few seconds before the first run.

## Slow runs: reading the timings

Each step ends with a line such as `[3] took 1.05s (read 0.61s, jev 0.24s, act 0.20s)`, and `session show` keeps the
same figures for every action and each run's total. The parts are what the run waited for, and they add up to the
step's time:

- `read`: `sim-use ui` readings. One reading takes about 0.5-0.7 s. A step reads two or three times (settling, the
  confirmation), up to 2 s more after an action that seemed to change nothing, and up to 5 s more each time it
  checks whether the screen moves on before handing over. So 1-3 s is normal, and 5-15 s on a step that hands over.
- `jev`: the Jev request, about 0.2-0.5 s. A second request (the retry with accessibility hints) doubles it. A slow
  `jev` with a normal `read` is the API or the network, not the device.
- `act`: the action. A tap takes about 0.2 s. A tap on a row that first has to be scrolled into view includes that
  scroll and the readings after it, and `wait` includes its pause.

**A warning that a sim-use screen read had no answer after 3 s** means the device's sim-use daemon hung. A hung
daemon's readings take 10-20 s instead of under one, or never answer. On iOS jev-sim-use handles this itself: it
cancels the reading, stops the device's daemon, reads the screen without it, and goes on; that step's `read` includes
the 3 s and the restart. This happens at most twice per run; after that, slow readings are waited out, and only a
reading with no answer after 30 s (a daemon that stopped answering altogether) stops the run with exit 3. Android readings
have no such deadline, so there a `read` far above the usual, on a step that did not hand over, points to the same
cause. To fix it by hand, whether after that exit or while running sim-use yourself:

```sh
jev-sim-use exec daemon status                      # a daemon listed as unreachable, or one with errno=60 in its log
jev-sim-use exec daemon stop --device <udid>        # the next sim-use command starts a fresh daemon
jev-sim-use session resume
```

If `daemon stop` reports `stopped: false`, the daemon process is not answering at all. Stop it again. If it still
does not go away, end its process by the pid that `daemon status` shows.

Restarting the daemon loses its report of apps that crashed since the last command. So if the app on screen after the
restart is a different one, the run stops as "app crashed or disappeared" even when the app may be fine. Look at the
screen, relaunch the app if it did crash, and resume.

## Before blaming the run

These came from classifying every failure across repeated runs against several apps.

**The app's accessibility sets the ceiling.** Most stubborn failures were rows exposed as loose text, images labelled
with asset names, unlabelled sliders, and look-alike buttons without hints. Screen-reader users hit the same walls,
and fixing the app removed failures no goal wording could.

**Recognise tool limits quickly.** sim-use cannot drag a SwiftUI slider, see a prompt drawn by another process, or
read most cells of a colour grid. When the same action fails the same way twice, do that step by hand with sim-use
through `exec` (by coordinates if needed) and resume. Retrying variations wastes the most time of anything.

**Check whether the data allows what you expect.** An option can be absent for a reason in the data: a colouring by
altitude appeared only for records with altitude changes, which a simulated route never has.

**Set up the start state deliberately.** Start comparable runs from the same screen with the same data. Launching
through `simctl` does not pass the environment an Xcode scheme sets (debug tokens, test credentials); pass it with
`SIMCTL_CHILD_<NAME>=…`.

**Keep test data traceable.** Use a staging backend and throwaway addresses (`…@example.com`) for sign-up flows, write
down every account and record created, and never exercise sign-up or purchase flows against production.
