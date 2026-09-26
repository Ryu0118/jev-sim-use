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
