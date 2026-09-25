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
- `mise run contract-test` — check the installed sim-use against `SimUseContract` (needs a booted device); run it after upgrading sim-use, then bump `SimUseBootstrap.testedVersion`
- See `.mise.toml` for the full task list (`mise tasks`)
- Git hooks in `.githooks/`: pre-commit runs gitleaks, format, lint, AST lint, docsync; pre-push runs AST lint
- Keep commits small and easy to revert

## Architecture

- `JevSimUse` (executable, binary `jev-sim-use`): `@main` only; starts `JevSimUseCommand`.
- `JevSimUseCLI` (+ `JevSimUseCLITests`): ArgumentParser commands `run` (default, positional goal), `session`
  (`list` / `show` / `tell` / `forget` / `resume`), `exec`
  (execv sim-use with arguments passed through), `doctor`, `config`. Thin: parse, `validate()`, build a request, call
  one Kit Runner, present the outcome, map failures to exit codes (`ExitStatus`: 2 setup, 3 runtime).
  - Commands conform to `ContextualCommand` and take a `CLIContext` (injectable `CLIOutput` + environment); `.live` is
    the only place the CLI reads `ProcessInfo`. CLI tests use `RecordingOutput` and a `FakeSimUse` script on `PATH`.
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
- `JevSimUseKit/Session`: the supervisor loop. A frontier agent reads `session show` and `exec ui`, adds facts with
  `session tell`, and `session resume`s; there are no per-run hint flags. Resume continues `history`, `notes`, and step
  numbers, but `maxSteps` and loop detection (`AgentProgress`) start fresh, so a stalled or step-limited run can move.
  `UserDirectories` is the one resolver for `HOME` / `XDG_*`.
- `JevSimUseKit/Configuration`: `JevSettings` resolves flag > env > `UserConfig` file > default for the base URL
  (`/v1/systemone` appended) and model. The key comes only from `TYPESAFE_API_KEY`. The tool speaks only TypeSafe's
  wire format; other providers go behind a compatible proxy. `UserConfigStore` uses `FileManagerProtocol`.
- `JevSimUseKit/Agent`: `AgentLoop` observe → plan → act. `JevStepPlanner` sends one request asking which
  operation to run, which target it would use, and whether it would finish the goal.
- `JevSimUseKit/Skill`: `SkillRunner` installs / uninstalls / prints the agent skill. `SkillBundle+Generated.swift` embeds
  `skills/jev-sim-use/SKILL.md` (SSoT) via `mise run generate-skill`, guarded by `SkillBundleDriftTests`. CLI:
  `jev-sim-use skill install|uninstall|print` (`--client claude|agents` or `--dest`), mirroring `sim-use init`.
- Distribution: `.claude-plugin/marketplace.json` + `.claude/plugins/jev-sim-use` (Claude Code),
  `.agents/plugins/marketplace.json` + `plugins/jev-sim-use` (Codex), `apm.yml` + `.apm/skills` (APM); skill dirs are
  symlinks to `skills/jev-sim-use`. `release.yml` bumps all manifest versions; `install.sh` is the curl installer.
  The docsync rule `skill-cli` ties SKILL.md to the CLI options and `AgentOutcome`: after changing them, update
  SKILL.md, run `mise run generate-skill`, then `docsync update-checksum`.

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
  `field_target` and `text_to_enter` when typing is possible), and noul `finishes` ("if the chosen operation works,
  is the whole goal satisfied?"). Code reads only the target that matches the chosen operation. Asking operation and
  target apart keeps a scroll or DONE from competing with every element for probability. Every question carries the
  same `JevStepPlanner.rules`, since target questions cannot see the operation answer. Do not add a second round trip.
- Completion: `done` with support >= `ActionPolicy.doneMinimum` (0.55; correct DONEs scored 0.58-0.99, a wrong one 0.49) exits 0, below it stops as
  `goalProbablyReached`; `finishes` >= 0.75 (set from runs: finishing actions scored 0.78-0.95, others at most 0.48) followed by a changed screen ends the run without another request (as in
  jev-use), which also settles relative goals the last screen cannot prove. Support is the weakest answer the action
  depends on (operation, target, text); targets with the same role and label pool their probability. For a reversible
  tap or element gesture, the operation factor is the sum over every element operation (they share `element_target`),
  so the gate checks what to act on, as jev-use does; the most probable gesture still runs. Targets whose label holds the
  goal's quoted item (`ScanFirst.namedTerms`, such as one colour name across seven swatches) pool too: any of them meets the goal. `StepPlan.factors`
  keeps each of those answers, and the progress line lists them when there is more than one.
- Every sim-use action is reachable: taps; element gestures (long-press, swipes, pinch, rotate); screen-level scrolls in
  four directions, go back (on iOS only when a `BackButton` shows a navigation stack: the left-edge swipe does
  nothing on a sheet or a tab's root, where Jev chose it at 0.79-0.88), a right-edge swipe, Return (`ios key 40`; a typed newline on Android, which has no `key`
  verb), and the platform's hardware buttons (`SimUseDeviceAction.available(on:)`); and pastes. A search field that
  shows results only on Return cannot finish without it. Not offered: double tap (two `tap` calls land ~0.4 s apart, outside iOS's window), `type` (Jev cannot
  tell whether `type` or `paste` will land; both need hardware keyboard events), raw `touch` / `multi-touch`, and
  non-actions (`screenshot`, `record-video`, `keyboard-state`, `app-state`, `viewer`, `daemon`); all stay reachable
  through `exec`. `ActionRisk` sets the bar: harmless (scrolls, back) at most 0.5 (TypeSafe reads less as genuinely unsure), reversible at `--min-confidence`,
  irreversible (tapping a control labelled 削除 / Delete / Remove / 消去) at least 0.6, as jev-use gates
  destructive picks; leaving the app (hardware buttons) 0.85, since sim-use cannot launch it again (a goal "go back
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
- Hints: iOS sim-use leaves `entries[].hint` empty but keeps `accessibilityHint` as the raw tree's `help`, so `ui` runs
  without `--no-raw` (5 to 16 KB, no slower) and `UISnapshot` copies each `help` to the entry at the same frame with
  a matching label. A hint shared by three or more elements (the status bar's gesture help) is dropped. Elements
  carry it as `hint`, which tells apart controls whose labels look alike (an AI rewrite and a plain edit).
- State (`PlanningState`) is named JSON: `goal`, `notes` (supervisor facts), `platform`, `screen.elements` (id `eN`,
  role, label, value, states, region), and `history` (`step`, `action`, `result`: "screen changed" / "no visible
  effect"). Questions refer to it by backticked paths. `AgentLoop` plans only on a settled screen (two readings that
  agree): a mid-transition reading made Jev tap again and hit an element of the next screen. After an action that left the screen
  as it was, it reads again back to back (a `ui` read takes ~0.6 s, so no sleep) until the screen changes or
  `AgentLoop.unchangedWait` (2 s) passes: a memo's save kept the form up for over a second. If Jev planned on
  a screen whose last action had not shown its effect, the screen is read once more right before acting and a stale
  plan is dropped (jev-ultrafast's freshness check); after a visible change that read is skipped.
- `-t` texts are `InputText` (`name=value`). `text_to_enter` offers only names; code taps the chosen field and pastes
  the value, which never reaches Jev ("select instead of generate").
  An element whose label or value contains a text's value carries that text's name as `shows_text` (only the name:
  the label is already in the state, and a masked password never matches), so "that memo" titled with `title` is
  findable after it was saved.
- Targets are named by element id with `null` criteria (the state carries role, label, value). Every enabled element
  is a target, whatever its role: Reminders exposes its rows only as `StaticText`. At most 255 per question.
  `blocked` hands over (`AgentOutcome.noActionFits`).
- Loops are code's job: an action already tried on a screen is never offered again there
  (`AgentProgress.ineffectiveActions`, keyed by screen because scrolls can bounce between two states), choosing one
  anyway hands over, and landing on screens already seen counts toward the stall limit. `history` tells Jev each
  step's effect ("screen changed" / "no visible effect"). Code never explores on Jev's behalf: `blocked` and
  low support hand over, as jev-ultrafast and jev-browser-use do; exploring moved away from the right screen. One
  narrow exception, `ScanFirst`: when the goal names items in the UI's script, none is visible, the screen is a list of rows to open (buttons or cells; a sheet listing features as text
  is not),
  and Jev would tap an unnamed element with support below 0.85 (a confident tap is Jev knowing the way), code scrolls
  that list once per title first (Jev's prior sent it into 一般
  for デベロッパ at 0.51-0.77, and wording did not move it). Sections entered and left are not offered again from
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

## Release

`.github/workflows/release.yml` bumps `Sources/JevSimUseKit/Version.swift` via `workflow_dispatch`.
Keep `THIRD_PARTY_LICENSES` in sync when dependencies change.
