# sim-jev-use

CLI that drives an iOS Simulator / Android device toward a natural-language goal. It shells out to
[sim-use](https://github.com/lycorp-jp/sim-use) (lycorp-jp, Apache-2.0) to observe and act, and asks
Jev through [swift-jev](https://github.com/d-date/swift-jev) (MIT) which action to take next.

## Development workflow

- `mise run setup` — install tools, configure Git hooks
- `mise run check` — format, lint, AST lint, build, test, docsync
- `mise run test` — run the test suite
- See `.mise.toml` for the full task list (`mise tasks`)
- Git hooks in `.githooks/`: pre-commit runs gitleaks, format, lint, AST lint, docsync; pre-push runs AST lint
- Keep commits small and easy to revert

## Architecture

- `SimJevUse` (executable, binary `sim-jev-use`): `@main` only; starts `SimJevUseCommand`.
- `SimJevUseCLI` (+ `SimJevUseCLITests`): ArgumentParser commands `run` (default, positional goal), `exec`
  (execv sim-use with arguments passed through), `doctor`, `config`. Thin: parse, validate, call one Kit Runner, present.
- `SimJevUseKit/Process`: `CommandRunning` seam; `ProcessCommandRunner` drains stdout and stderr
  concurrently, because `ui --json` output can exceed the pipe buffer.
- `SimJevUseKit/SimUse`: locate sim-use on `PATH` (not via `/usr/bin/env`, so "not installed" is
  distinct from exit 127), version gate (`SimUseBootstrap.minimumVersion`), device pinning, and
  `--json` envelope decoding.
- `SimJevUseKit/Configuration`: `JevSettings` resolves flag > env > `UserConfig` file > default for the base URL
  (`/v1/systemone` appended) and model. The key comes only from `TYPESAFE_API_KEY`. The tool speaks only TypeSafe's
  wire format; other providers go behind a compatible proxy.
- `SimJevUseKit/Agent`: `AgentLoop` observe → plan → act. `JevStepPlanner` sends one request with a
  noul `goal_reached` and a runtime-built choice `next_action`.

## sim-use contract (verified against v0.14.0)

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
- Choice options are built at runtime, so typed `ChoiceQuestion` / `RoutingPolicy.decide` for choices do not
  apply. Read `answers[name]`, validate the chosen name against the offered options, and threshold with the
  policy's public fields.
- State plus the longest question must fit in 32k tokens; `ActionCatalog` caps tap targets. A 422 is
  surfaced as `PlanningError.rejected`.
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

`.github/workflows/release.yml` bumps `Sources/SimJevUseKit/Version.swift` via `workflow_dispatch`.
Keep `THIRD_PARTY_LICENSES` in sync when dependencies change.
