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
  (`list` / `show` / `tell` / `resume`), `exec`
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
- `JevSimUseKit/Agent`: `AgentLoop` observe → plan → act. `JevStepPlanner` sends one request with a
  noul `goal_reached` and a runtime-built choice `next_action`.
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
- `doctor` decodes one real `ui --json --no-raw` response, so output changes surface before a run.
- After upgrading sim-use: boot a simulator, run `mise run contract-test` (`JevSimUseContractTests`, skipped in the
  normal test run), then bump `testedVersion`.

- Always pass `--json` and the same `--device`: `tap @N` resolves against the outline sim-use cached for
  that device on the last `ui` call.
- In `--json` mode errors are `{"ok":false,"error","hint"?}` on **stdout** with exit 1. Argument
  validation errors (exit 64) are plain text on stderr, with no envelope.
- Decode leniently: optional keys, unknown keys ignored. `udid` was removed in 0.10.0 (`deviceId` is canonical).
- `gesture scroll-up` pages *down* (finger direction). `AgentAction` names options by intent.
- No launch verb and no wait verb exist. Text input uses `paste` (Unicode-safe on iOS, unlike `type`).

## Jev constraints

- Use the TypeSafe skill (`typesafe@typesafe-ai`, enabled in `.claude/settings.json`) when designing or
  changing Jev questions. The live docs at https://docs.typesafe.ai are the source of truth.
- One request per step with two questions: noul `goal_reached` and choice `next_action`. Do not add a second
  round trip or questions whose answers no code uses; speed is the point.
- State (`PlanningState`) is named JSON: `goal`, `notes` (supervisor facts, referenced by both questions), `platform`, `screen.elements` (id `eN`, role, label, value, states,
  region), and `history` (`step`, `action`, `screen_changed`). Questions refer to it by backticked paths.
- Tap options are named by element id with `null` criteria; other options carry a description. `ActionCatalog` offers
  only pressable roles (not `StaticText` / `Heading` / `GenericElement` / `Group` / `Image`), at most 200 taps within
  Jev's 255-option limit, and always `none_of_these`, which hands over (`AgentOutcome.noActionFits`).
- Code, not Jev, handles search and loops: an action already tried on a screen is never offered again there
  (`AgentProgress.ineffectiveActions`, keyed by screen because scrolls can bounce between two states); landing on
  screens already seen counts toward the stall limit; when Jev picks `none_of_these`, `Exploration` scrolls down, then
  goes back, once per screen, before handing over.
- Jev reliably picks a visible target but does not know where an off-screen setting lives; a supervisor `session
  tell` fixes that (Dark Mode: support 0.26 without the note, 1.00 with it). Toggles are shown as `on` / `off`, and Jev
  judges them correctly once the switch really flips. iOS switches ignore sim-use's instant row-centre tap, so
  `AgentLoop` taps a toggle's trailing edge with `--duration 0.05` (`DeviceDriving.tapSwitch`). Scrolling / going back
  need at most 0.3 support.
- Choice options are built at runtime, so typed `ChoiceQuestion` reads do not apply: read `answers[name]` and validate
  the chosen name against the offered options.
- Thresholds are split: `goalPolicy` (default `RoutingPolicy`, success only on `.auto`) and `ActionPolicy`
  (`--min-confidence` for reversible actions; pasting needs at least 0.85). `StepPlan.support` adds up probability
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
