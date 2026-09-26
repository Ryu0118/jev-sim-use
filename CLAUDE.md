# jev-sim-use

CLI that drives an iOS Simulator / Android device toward a natural-language goal. It shells out to
[sim-use](https://github.com/lycorp-jp/sim-use) (lycorp-jp, Apache-2.0) to observe and act, and asks
Jev through [swift-jev](https://github.com/d-date/swift-jev) (MIT) which action to take next.

Why it exists: speed. Each step is one small typed Jev call instead of a frontier LLM agent spending a reasoning turn
per tap. Keep it that way: one Jev request per step, no extra round trips, and deterministic work stays in code.

## Development workflow

- `mise run setup` — install tools, configure Git hooks
- `mise run check` — format, lint, AST lint, build, test, docsync
- `mise run test` — run the test suite
- `mise run e2e -- <udid>` — the real-simulator E2E run (see Testing); not in CI
- `mise run contract-test` — check the installed sim-use against `SimUseContract` (needs a booted device); run it after upgrading sim-use, then bump `SimUseBootstrap.testedVersion`
- See `.mise.toml` for the full task list (`mise tasks`)
- Git hooks in `.githooks/`: pre-commit runs gitleaks, format, lint, AST lint, docsync; pre-push runs AST lint
- Keep commits small and easy to revert

## Testing

E2E is the primary proof of behaviour. Unit tests are only for what truly needs one (regressions, critical
guards, edge cases, and paths the E2E never runs): list those failure modes first, write their tests, then implement.
Never write unit tests after the code.

- E2E: `mise run e2e -- <udid>` (`scripts/e2e-simulator.sh`) runs locally against a real simulator with the real
  sim-use and the real Jev API (`TYPESAFE_API_KEY`). The release binary works through a fixed set of goals in the
  simulator's built-in Settings app: a multi-screen route, a switch, a row reached by scrolling, typing into search
  with `-t`, a hand-over followed by `session tell` / `resume`, and a goal already met. Each goal is judged by reading
  the screen afterwards, never by the exit status alone, and keeps its exit status, stdout / stderr with timed step
  lines, Jev cost, `session show`, the final `sim-use ui` reading, and a screen recording under `.e2e/<timestamp>/`
  (gitignored). It is not in CI; paste its summary table into every behaviour-changing PR. Keep raw logs local.
- Unit tests run in CI with build and lint.
- `mise run contract-test` guards the sim-use output contract (`SimUseContract`) against the installed sim-use.

## Architecture

- `JevSimUse` (executable, binary `jev-sim-use`): `@main` only; starts `JevSimUseCommand`.
- `JevSimUseCLI` (+ `JevSimUseCLITests`): ArgumentParser commands `run` (default, positional goal), `session`
  (`list` / `show` / `tell` / `forget` / `resume`), `exec`
  (execv sim-use with arguments passed through), `doctor`, `config`. Thin: parse, `validate()`, build a request, call
  one Kit Runner, present the outcome, map failures to exit codes (`ExitStatus`: 2 setup, 3 runtime).
  - Commands conform to `ContextualCommand` and take a `CLIContext` (injectable `CLIOutput` + environment); `.live` is
    the only place the CLI reads `ProcessInfo`. CLI tests cover argument parsing.
- `JevSimUseKit` Runners (return values, never print):
  - `RunGoalRunner` (`Agent/`): resolves `JevSettings`, pins the device (`--device` > `$SIM_USE_DEVICE` > the only
    usable device), builds the `RoutingPolicy`, runs `AgentLoop`, reports `RunGoalEvent`s. Every run belongs to a
    session (`SessionStart.new` or `.resume`), saved before and after the loop and deleted once the goal is reached.
    Unfinished sessions expire a week after they last changed (`SessionStore.timeToLive`, pruned on every run and
    `session` command).
  - `SessionRunner` (`Session/`): list / show / tell on `SessionStore` (`$XDG_STATE_HOME/jev-sim-use/sessions`).
  - `DoctorRunner` (`Doctor/`): sim-use, device (reads the screen once), and Jev settings checks → `DoctorReport`.
  - `ConfigRunner` (`Configuration/`): get / set (validated) / unset / list on `UserConfigStore`.
  - `FailureCategory` classifies Runner errors as setup vs runtime.
- `JevSimUseKit/Process`: `CommandRunning` seam; `SubprocessCommandRunner` runs commands through swift-subprocess 1.0
  via ProcessRunning, which collects both streams concurrently and stops reading once the child exits.
- `JevSimUseKit/SimUse`: locate sim-use on `PATH` through `FileManagerProtocol` (not via `/usr/bin/env`, so "not
  installed" is distinct from exit 127), version gate, device pinning, and `--json` envelope decoding.
  `SimUseDaemonWatchdog` gives every iOS `ui` read through the daemon a 3 s deadline (healthy reads 0.45-0.67 s, a
  hung daemon's 10-20 s or never): past it the read is cancelled, `daemon stop --device <udid> --timeout 1` runs, and
  the screen is read with `SIM_USE_NO_DAEMON=1`; at most twice per run, reported as a warning. After that reads are
  waited out up to 30 s (`SimUseError.readTimedOut` past it): a natural hang answered in about 10 s and a fresh daemon
  hung again within a minute, so failing sooner would end runs that finish today. Only the deadline triggers it; error envelopes are thrown as before. A stopped daemon loses its
  report of apps that disappeared, and a no-daemon read has none, so an app no longer on screen after a replacement
  counts as disappeared. `daemon stop` on a daemon that stopped answering reports `stopped: false` (and took 6 s at
  the default `--timeout`). Android reads have no deadline: their normal time was never measured.
- `JevSimUseKit/Session`: the supervisor loop. A frontier agent reads `session show` and `exec ui`, adds facts with
  `session tell`, and `session resume`s; there are no per-run hint flags. Resume continues `history`, `notes`, and step
  numbers, but `maxSteps` and loop detection (`AgentProgress`) start fresh, so a stalled or step-limited run can move.
  Each action's `HistoryEntry` and each `SessionRun` keep a `StepTiming` (optional, so older files decode); it never
  reaches Jev's `history`.
  `UserDirectories` is the one resolver for `HOME` / `XDG_*`.
- `JevSimUseKit/Configuration`: `JevSettings` resolves flag > env > `UserConfig` file > default for the base URL
  (`/v1/systemone` appended) and model. The key comes only from `TYPESAFE_API_KEY`. The tool speaks only TypeSafe's
  wire format; other providers go behind a compatible proxy. `UserConfigStore` uses `FileManagerProtocol`.
- `JevSimUseKit/Agent`: `AgentLoop` observe → plan → act, as a state machine: `AgentLoopState` (observing, planning,
  deciding, finished) with one transition each in `AgentLoop+Transitions`; `AgentLoopContext` carries what outlives a
  step (progress, the acted-on screen, re-plan and disagreement counters, the step's `StepTiming`). Each step ends
  with a `[n] took …s (read …, jev …, act …)` line: the loop's own waits, which never overlap, so the confirming read
  under Jev's request counts only for the wait after Jev answered. `JevStepPlanner` sends one request asking which
  operation to run, which target it would use, whether it would finish the goal, and whether its tap is irreversible.
- `JevSimUseKit/Skill`: `SkillRunner` installs / uninstalls / prints the agent skill. `skills/jev-sim-use/` is the only
  copy (SSoT: SKILL.md plus `references/*.md`, which SKILL.md links to and `skill install` writes alongside it): the
  `EmbedSkill` build tool plugin (`BuildPlugins/`, run through the `EmbedSkillTool` executable) generates
  `SkillBundle.files` from it into the build directory on every build, SKILL.md first and the references sorted, each
  file's bytes in a raw string (a file holding the terminator fails the build). Releases ship the executable alone,
  so there is no resource bundle. Editing the Markdown is enough; `SkillEmbeddingTests` checks the plugin's output
  against the directory. The plugin targets set `path:` because `plugins/` is the agent plugin (and, on a
  case-insensitive disk, SwiftPM's default `Plugins`). CLI:
  `jev-sim-use skill install|uninstall|print [<path>]` (`--client claude|agents` or `--dest`), mirroring `sim-use init`.
- Distribution: `.claude-plugin/marketplace.json` + `.claude/plugins/jev-sim-use` (Claude Code),
  `.agents/plugins/marketplace.json` + `plugins/jev-sim-use` (Codex), `apm.yml` + `.apm/skills` (APM); skill dirs are
  symlinks to `skills/jev-sim-use`. `release.yml` bumps all manifest versions; `install.sh` is the curl installer.
  The docsync rule `skill-cli` ties SKILL.md to the CLI options and `AgentOutcome`: after changing them, update
  SKILL.md, then `docsync update-checksum`.

## sim-use contract (verified against v0.14.0)

- sim-use is used only through its CLI and `--json` output. Every subcommand, flag, and gesture name lives in
  `SimUseContract` (SSoT); `SimUseContract.helpExpectations` lists what each `--help` must mention.
- `SimUseBootstrap.minimumVersion` refuses older sim-use; `testedVersion` is the newest verified one. Newer versions run
  with a warning (`SimUseConnection.versionWarning`, shown by `run` and `doctor`), and unparseable output adds a hint
  pointing at `exec --version` and the contract test.
- `doctor` decodes one real `ui --json` response, so output changes surface before a run.
- After upgrading sim-use: boot a simulator, run `mise run contract-test` (`JevSimUseContractTests`, skipped in the
  normal test run), then bump `testedVersion`.

- Always pass `--json` and the same `--device`: `tap @N` resolves against the outline sim-use cached for
  that device on the last `ui` call.
- In `--json` mode errors are `{"ok":false,"error","hint"?}` on **stdout** with exit 1. Argument
  validation errors (exit 64) are plain text on stderr, with no envelope.
- Decode leniently: optional keys, unknown keys ignored. `udid` was removed in 0.10.0 (`deviceId` is canonical).
- `gesture scroll-up` pages *down* (finger direction). `AgentAction` names options by intent.
- No launch verb and no wait verb exist. Text input uses `paste` (Unicode-safe on iOS, unlike `type`).
- iOS `paste` is a Cmd+V key event: without a connected hardware keyboard the simulator drops it and sim-use still
  reports `ok`, and `paste --via-menu` found no Paste item in Reminders or Safari. `SimUseClient.paste` reads
  `keyboard-state` first and throws `SimUseError.hardwareKeyboardRequired` (setup, exit 2) while the software keyboard
  is up.

## Jev constraints

- Use the TypeSafe skill (`typesafe@typesafe-ai`, enabled in `.claude/settings.json`) when designing or
  changing Jev questions. The live docs at https://docs.typesafe.ai are the source of truth.
- One request per step, the jev-ultrafast shape: choice `operation` (tap, each element gesture, `enter_text`, each
  screen-level action, `done`, `blocked`), speculative target choices (`element_target` shared by tap and gestures;
  `field_target` and `text_to_enter` when typing is possible), noul `finishes` ("if the chosen operation works,
  is the whole goal satisfied?"), noul `satisfied` ("is every part of the goal already satisfied?"), and, when a tap is
  offered, noul `irreversible` ("would tapping the element this step
  would choose lose data or state that going back cannot restore?"). Code reads only the target that matches the chosen operation. Asking operation and
  target apart keeps a scroll or DONE from competing with every element for probability. `PlanningRules` builds the
  rules from the step's offered operations: sentences about scrolling, going back, waiting, toggling, or typing are left
  out when Jev cannot choose that operation (the full menu gives the full text). Target questions cannot see the
  operation answer and the request has no shared instructions field, so the rules travel once as the state's `rules`
  and every question opens with `JevStepPlanner.rulesPointer` (`rules` is guidance, `screen` is data). Do not add a
  second round trip.
- Completion: DONE's support is the `satisfied` answer, not DONE's share of `operation`, where it competed with the
  operation that finishes the goal (after typing a query: done 0.58, press_return 0.33, and the run exited 0 without
  Return). When `satisfied` is below 0.5, DONE keeps only the share `satisfied` backs and the rest goes to the other
  operations in proportion (`JevStepPlanner.notDone`), so the finishing operation runs; a response without the answer
  is read as before. DONE with support >= `ActionPolicy.doneMinimum` (0.55) exits 0, below it stops as
  `goalProbablyReached`. A screen that carries the goal's last named title one step early (a settings screen titled
  like the list it leads to) still reads as satisfied: nothing on screen tells the two apart. `finishes` is asked and logged on every step line but does not end a run: after any action
  Jev judges the new screen in another request (a changed screen once came from elsewhere, and a run ended as reached
  on a tap that never landed). Support is the weakest answer the action
  depends on (operation, target, text); targets with the same role and label pool their probability. For a reversible
  tap or element gesture, the operation factor is the sum over every element operation (they share `element_target`),
  so the gate checks what to act on, as jev-use does; the most probable gesture still runs. `StepPlan.factors`
  keeps each of those answers, and the progress line lists them when there is more than one.
- Every sim-use action is reachable: taps; element gestures (long-press, swipes, pinch, rotate); typing that appends
  (`enter_text`) or replaces (`replace_text`, `paste --replace`, offered only when a field holds a value: appending
  left the old title in front of the new one; the two are `Operation.equivalents`, so their support adds up and the
  more probable one runs, since apart they split an empty title 0.53 / 0.43 on a form whose other fields showed
  placeholders, and typing a text a field already holds exactly always replaces); screen-level scrolls in
  four directions, go back (on iOS only when a `BackButton` shows a navigation stack, and done by tapping it, since a
  map on a detail screen swallowed the left-edge swipe; the swipe does
  nothing on a sheet or a tab's root, where Jev chose it at 0.79-0.88), a right-edge swipe, Return (`ios key 40`; a typed newline on Android, which has no `key`
  verb), Escape on iOS (`ios key 41`, group `keys`: it closes a context menu, whose backdrop is never a target, and
  closed a filled form without asking, so it is irreversible), a two-finger drag from a list's first shown row to its
  last on iOS (`multi-touch`, group `two-finger`, offered where rows line up: it starts UIKit multiple selection; as an
  element gesture Jev aimed it at the button whose menu also selects rows), a pull to refresh on iOS (group `scroll`:
  one `swipe` down the middle of the screen from 30% to 85% of its height in 0.3 s; the vertical scroll preset, about
  210 pt over 1.5 s, and an element swipe down a 44 pt row only drew the refresh control's pull progress and let it
  go, which is why a refresh goal never refreshed; this pull filled the control every time and held a refresh open in
  most runs), and the platform's hardware buttons
  (`SimUseDeviceAction.available(on:)`) except Siri (one press left `sim-use ui` unreadable until a reboot); and
  pastes. A search field that shows results only on Return cannot finish without it. Not offered, each for a reason
  that holds against sim-use 0.14.0: double tap (two `tap` calls land ~0.4 s apart, outside iOS's window), drag and
  drop (no primitive holds and then moves; split `touch --down` / `--up` did not move a slider either), `type` (Jev
  cannot tell whether `type` or `paste` will land; both need hardware keyboard events), keys whose effect `sim-use ui`
  does not show (Tab, arrows, Cmd+A: focus, caret, and selection are not in the tree; Backspace did nothing without
  focus and deleted four characters for "the last character", since Jev cannot count earlier presses), two-finger
  taps and long-presses (they zoom a map, which the tree does not show), raw `touch`, and
  non-actions (`screenshot`, `record-video`, `keyboard-state`, `app-state`, `viewer`, `daemon`); all stay reachable
  through `exec`. `ActionRisk` sets the bar: harmless (scrolls, back) at most 0.5 (TypeSafe reads less as genuinely unsure), reversible at `--min-confidence`,
  irreversible at least 0.6, as jev-use gates destructive picks. A tap is irreversible unless Jev's `irreversible`
  answer is below 0.35 (`ActionPolicy.reversibleTapMaximum`, the undecided band's lower edge), so a label in any
  language is judged by what the control does and a missing or unsure answer fails safe (`StepPlan.risk`); a stub server
  that omits the key gets the irreversible bar for every tap. The answer's "no" side names what an app can undo (closing,
  cancelling a clean edit, archiving, clearing a favorite or other mark): opening, navigating, closing, cancelling a
  clean edit, archiving, and (un)favouriting scored 0.07-0.31 over three passes, deleting and discard confirmations
  0.76-0.85, and cancelling an edit with typed changes 0.53-0.62 (irreversible: an app may discard them unasked);
  before the wording named them, the undoable ones scored up to 0.57; leaving the app (hardware buttons) 0.85, since sim-use cannot launch it again (a goal "go back
  to the home screen", meaning the app's tab, pressed Home at 0.66 and finished in another app). The shared rules also say a word that could
  name a place in the app or on the device (home, settings, search, back) means the app's own first. Typing is reversible (it submits nothing and is cleared as easily): 0.85 held
  correct email / password steps back at 0.65-0.84, and no reference agent gates typing higher than a tap. Horizontal element swipes travel 40% of the width, which reveals a row's actions (Delete) instead of
  the full swipe that deletes a Reminders row without asking. Sideways scrolls pass
  `--duration 0.3` (the default 0.5 s does not turn a page); top- and bottom-edge swipes are not offered (no effect on
  iOS 26, and Control Center blinds `sim-use ui`).
- Sliders: SwiftUI often labels a slider with its raw position (`0.1206…`), so `UISnapshot.caption(ofSlider:)` names
  it after the text just above and shows that row's displayed value (`Recording Interval` / `25 m`), and its state says a swipe,
  not a tap, moves it. On the iOS 26.5 simulator no sim-use drag moved a SwiftUI slider (swipes from the thumb or the
  track, slow drags, split `touch --down` / `--up`; `--pre-delay` waits before touching down), so a slider goal
  stops there until sim-use can hold then move.
- Known limit: an empty iOS search field reports its placeholder as its value, with nothing else in the raw tree to
  tell it from typed text, so `replace_text` is offered there and Jev may press Return before typing (2 of 8 first
  steps in the E2E search goal). Telling them apart would take a label heuristic, which the tool does not use.
- Hints: iOS sim-use leaves `entries[].hint` empty but keeps `accessibilityHint` as the raw tree's `help`, so `ui` runs
  without `--no-raw` (5 to 16 KB, no slower) and `UISnapshot` copies each `help` to the entry at the same frame with
  a matching label. A hint shared by three or more elements (the status bar's gesture help) is dropped. Hints stay
  out of the first request (`PlanRequest.includesHints`), so an app that hints every control does not grow every
  step. The raw tree also marks the system status bar's items (time, signal, battery, the Dynamic Island)
  with the trait `StatusBarElement`; `UISnapshot.withoutStatusBar` drops those entries when a snapshot is decoded, so
  they are never targets, state, or part of `identity`: Jev tapped the clock instead of going back, and the ticking
  clock made an unchanged screen look new. When a step would hand over (low support or BLOCKED) and the screen has a hint, the loop asks once more with
  elements carrying `hint`: the one exception to one request per step, spent only where the run would otherwise stop.
- State (`PlanningState`) is named JSON: `rules`, `goal`, `notes` (supervisor facts), `platform`, `screen.elements` (id `eN`,
  role, label, value, states, region), and `history` (`step`, `action`, `result`: "screen changed" / "no visible
  effect"). Questions refer to it by backticked paths. `AgentLoop` plans only on a settled screen (two readings that
  agree): a mid-transition reading made Jev tap again and hit an element of the next screen. After an action that left the screen
  as it was, it reads again back to back (a `ui` read takes ~0.6 s, so no sleep) until the screen changes or
  `AgentLoop.unchangedWait` (2 s) passes: a memo's save kept the form up for over a second. If Jev planned on
  a screen whose last action had not shown its effect, the screen is read once more right before acting and a stale
  plan is dropped (jev-ultrafast's freshness check); after a visible change that read is skipped. Before handing over (low
  support, BLOCKED, probably done), the screen is read once more and the step planned again if it moved on, at
  most `AgentLoop.staleReplanLimit` times per step: a saved item reached its list a second after the screen changed.
- `-t` texts are `InputText` (`name=value`). `text_to_enter` offers only names; code taps the chosen field and pastes
  the value, which never reaches Jev ("select instead of generate").
  An element whose label or value contains a text's value carries that text's name as `shows_text` (only the name:
  the label is already in the state, and a masked password never matches), so "that memo" titled with `title` is
  findable after it was saved.
- Targets are named by element id with `null` criteria (the state carries role, label, value). Every enabled element
  is a target, whatever its role: Reminders exposes its rows only as `StaticText`. At most 255 per question.
  Except a pop-up menu's dismiss backdrop (`UISnapshot.backdrop`: a `Button` spanning the screen with labelled
  elements deeper inside it), left out of targets and state: Jev tapped it at 0.35-0.40 instead of the menu's item.
  While it shows, the state carries `screen.opened_by` (the last tap that changed the screen,
  `AgentProgress.menuOpener`) and the rules gain one sentence about it, so the items read as choices for that control.
  `blocked` hands over (`AgentOutcome.noActionFits`).
- Loops are code's job: an action already tried on a screen is never offered again there
  (`AgentProgress.ineffectiveActions`, keyed by screen because scrolls can bounce between two states), choosing one
  anyway hands over, and landing on screens already seen counts toward the stall limit. The same action repeated on a
  screen showing the same elements as one it was taken on (`UISnapshot.skeleton`) hands over once its last
  `AgentProgress.repeatLimit` repeats each left the elements' values and states as a state already seen in the run
  (`AgentProgress.isFutileRepeat`): a row tapped 26 times never opened while a relative time on it ticked, so every
  screen looked new. Elements seen changing between the planned and the confirming reading, with no action between
  (`AgentProgress.noteReading`), tick on their own and are left out of those states; a counter whose value goes up
  with each tap keeps going, and a switch flipped back and forth hands over once its states repeat. `history` tells Jev each
  step's effect ("screen changed" / "no visible effect"; for an action that can work without changing the screen,
  `pull_to_refresh`, an unchanged screen reads "done; ... not a failure" (`PlanningState.Step.unseenEffect`): as "no
  visible effect", a refresh that had run looked failed, and Jev pulled again and handed over in 2 of 6 runs). Code never explores on Jev's behalf: `blocked` and
  low support hand over, as jev-ultrafast and jev-browser-use do; exploring moved away from the right screen. A
  former exception, `ScanFirst`, scrolled a list once before an unsure dive when the goal quoted a non-Latin item
  name; it was removed because it matched strings in one script only, and measured runs (an item below the fold, in
  a Japanese and an English UI, 5 each) finished the same without it. An unsure dive hands over on support instead.
  Sections entered and left are not offered again from
  the same title (`AgentProgress.exploredElements`).
- Jev reliably picks a visible target but does not know where an off-screen setting lives; a supervisor `session
  tell` fixes that (Dark Mode: support 0.26 without the note, 1.00 with it). Toggles are shown as `on` / `off`, and Jev
  judges them correctly once the switch really flips. iOS switches ignore sim-use's instant row-centre tap, so
  `SimUseClient.tap(alias:on:)` taps a toggle's trailing edge with `--duration 0.05`, and a full-width
  value `Button` (`UIEntry.isValueRow`, a SwiftUI ColorPicker row, whose well ignored a centre tap) 18 pt in the same way. Loop detection compares screens
  by `UISnapshot.identity` (elements and state, no frames), so a scroll that bounces counts as no change. Scrolling / going back
  need at most 0.5 support.
- Choice options are built at runtime, so typed `ChoiceQuestion` reads do not apply: read `answers[name]` and validate
  the chosen name against the offered options.
- Thresholds are split: `goalPolicy` (default `RoutingPolicy`, success only on `.auto`) and `ActionPolicy`
  (`--min-confidence` for reversible actions, typing included; irreversible actions need at least 0.6). `StepPlan.support` adds up probability
  split across options that do the same thing.
- The default model is pinned to `jev-1.13.0`; re-run real-device goals before moving it. Accuracy is lower for CJK
  text, so re-check thresholds on Japanese UIs.
- State plus the longest question must fit in 32k tokens. Sessions grow, so only the last 20 `history` entries and
  10 `notes` are sent. A 422 is surfaced as `PlanningError.rejected`.
- Never call the real API from `swift test`; use `StubTransport`.

## Coding rules

Read these before writing or reviewing code. They are the source of truth (`.claude/rules` is a symlink to `.agents/rules`):

- `.agents/rules/coding-rules.md` — SSoT / DRY / SOLID, layering (executable / CLI / Kit), Runners, side effects behind protocols (swift-subprocess via ProcessRunning, FileManagerProtocol), errors, tests
- `.agents/rules/swift-coding.md` — files, access control, comments, abstraction, concurrency, testing conventions
- `.agents/rules/code-review.md` — review and refactoring checklist
- `.agents/rules/lint-and-format.md` — what SwiftFormat, SwiftLint, and the AST linter enforce
- `.agents/rules/workflow.md` — commit size, Git and agent hooks, docsync, CI

Access policy: use `package` for anything shared across modules in this package; `public` only for symbols consumed outside it.

## Public writing

Commits, PR titles and bodies, issues, review comments, code, tests, and docs are public. Never name or describe
the private apps, simulators, or devices a goal was tried on: no app names, simulator names, UI labels, screen text,
item titles, or goal wording copied from them. Describe them generically ("a test app on an iOS simulator", "the type
pop-up menu", "the dismiss button") and keep raw logs local.

## Release

`.github/workflows/release.yml` bumps `Sources/JevSimUseKit/Version.swift` via `workflow_dispatch`.
It builds the universal binary with `scripts/build-release.sh` (`--build-system swiftbuild`: Swift 6.3's default
build system cannot resolve the EmbedSkill plugin in a multi-arch build), which CI's `Universal Release Build` job
also runs on every change.
Keep `THIRD_PARTY_LICENSES` in sync when dependencies change.
