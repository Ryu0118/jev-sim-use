# Lessons from driving real apps with jev-sim-use

These come from running the same goals round after round against several third-party iOS apps and classifying every
failure. They apply to agent-driven UI work generally, not only to this tool.

## Success is a claim until the screen proves it

Exit 0 means Jev judged the goal reached. Twice that judgment was wrong: once on a detail screen inside the tab it
was asked to return to, once after a run wandered into another app and finished a same-named item there. Check the
end state with `exec ui` before building on it, and read it after the app settles: a saved item can take a second
or two to appear in a list, so read, wait about two seconds, and judge the second reading.

## Ambiguity causes more wrong successes than weak judgment

Every wrong success traced back to a goal that allowed two readings: "home" (the app's tab or the device's Home
Screen), "edit" (the editor or an AI assistant), "post a record" (open the item or add a new one). Jev resolves
ambiguity plausibly, not necessarily as you meant. Name the end state in the app's own terms, and say which feature
when two look alike.

## A hand-over is cheap; a wrong action is not

Lowering `--min-confidence` to push a stuck run through once let it press the Home button, leave the app, and report
success in another app. Scrolls and back cost a step when wrong; a tap on the wrong control or leaving the app can
cost the whole run, or change data. When a run stops, add the missing fact with `tell` rather than lowering the bar.

## The app's accessibility bounds what any agent can do

Most of the stubborn failures were not the model's: tappable rows exposed as loose text, images labelled with asset
names, sliders labelled with their raw position, look-alike buttons without hints. Screen-reader users hit the same
walls. Fixing the app (one element per tappable row, a button trait, real labels, values with units, hints for
look-alike controls) helped both, and removed failures that no prompt wording could.

## Split long flows and verify between them

Uncertainty compounds: ten steps at 90% each succeed about a third of the time. A flow such as create, edit,
favourite, convert, and complete stalled at a different step on each attempt. Run it as a few goals, check each end
state, and `resume` or start the next goal from there.

## Recognise tool limits quickly

Some things sim-use cannot do on a simulator: drag a SwiftUI slider, see a prompt drawn by another process, read most
cells of a colour grid, or trust an instant tap on every control. When the same action fails the same way twice,
treat it as a limit: do that step by hand or with a coordinate tap, then continue. Retrying variations wastes the
most time of anything.

## Set up the start state deliberately

Runs are only comparable when they start from the same screen with the same data. Launch the app, wait a few
seconds, clear late prompts, and remove data left by earlier runs. Launching through `simctl` does not pass the
environment an Xcode scheme sets (debug tokens, test credentials); pass it with `SIMCTL_CHILD_<NAME>=…`.

## Keep test data traceable

Use a staging backend and throwaway addresses (`…@example.com`) for sign-up flows, and write down every account
created so it can be removed later. Never exercise sign-up or purchase flows against production.
