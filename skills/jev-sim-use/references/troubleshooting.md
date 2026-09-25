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

**Something visible that `exec ui` does not list.** A system prompt from another process (a password-save alert),
most cells of a colour grid, a popover's close button. Use `exec screenshot` and `exec tap -x … -y …`.

**A tap that changes nothing on a row that opens a sheet or a picker.** Some controls ignore an instant tap. Hold it
briefly: `exec tap -x … -y … --duration 0.1`.

**Place words** ("home", "settings", "search", "back"). Jev reads them as the app's own first (a tab, screen, or
button by that name) and as the device's only when the app has none. Say "the device's Home Screen" if you mean to
leave the app; sim-use cannot open it again.

**Creating something.** Say "and save it". Typed text is not saved, and Jev does not treat it as done.

**Search.** A search field that acts on Return is fine; Jev can press Return. A results screen without a heading
often ends as "probably reached"; confirm with `exec ui`.

**Slow submits.** After an action that changes nothing, the run keeps reading for up to 2 s. A sign-up or save that
takes longer can be pressed twice; check the result before resuming.

**Interruptions.** Rating requests, tracking prompts, notification permission, password-save alerts, and promo
banners can appear seconds after launch and derail a run midway. Clear them before starting, and after launching
an app give it a few seconds before the first run.
