# Coding Rules

Design rules for this package. Language-level
conventions live in `swift-coding.md`; lint-enforced details in `lint-and-format.md`.

## Principles

- **SSoT (single source of truth).** Every fact has exactly one owner: a config key, an environment variable name, a
  default value, a CLI contract, an output format. Everything else derives from it. When a fact must be duplicated
  across a boundary you do not control (another tool's CLI flags, a server's wire format), add a drift test that fails
  when the two disagree.
- **DRY, but not prematurely.** Deduplicate knowledge (rules, constants, decisions), not code that merely looks alike.
  Extract a shared helper only when the guard, the branches, and the result semantics are the same; otherwise leave
  the near-duplicates.
- **SOLID**, as practiced here:
  - *Single responsibility*: one use case per Runner, one concern per file, one type per file. A loader only locates,
    reads, and decodes; validation, defaulting, and construction are separate steps.
  - *Open/closed*: add a capability by adding a type that conforms to an existing protocol, not by growing `switch`es
    across the codebase.
  - *Liskov*: a fake or alternative implementation must honour the protocol's documented contract (errors, ordering,
    cancellation), so tests exercise real behaviour.
  - *Interface segregation*: small, focused capability protocols (`-ing` names) instead of one catch-all service.
  - *Dependency inversion*: the Kit declares the protocols it needs; the composition root (CLI / executable) supplies
    the live implementations.
- **YAGNI.** Do not add options, layers, or protocols without a caller that needs them now.

## Targets and layers

- `Sources/<Name>/` (executable) contains `@main` and composition only: build the live dependencies and hand control
  to the CLI target. No `ParsableCommand`s here.
- `Sources/<Name>CLI/` (library) holds the ArgumentParser commands and the thin adapters to the outside world
  (argument passthrough, `execv`, exit-status mapping, presenting results). It has its own `<Name>CLITests` target.
- `Sources/<Name>Kit/` holds all use-case logic. It never parses `argv`, calls `exit`, prints, or reads
  `ProcessInfo` / `FileManager.default` inside methods.
- Dependencies point one way: executable → CLI → Kit.

## Commands are thin; Runners own the use case

- A command does only: parse → validate (`validate()`, throwing `ValidationError` → exit 64) → build a Kit input
  (`<UseCase>Request` or plain values) → construct **one** Kit Runner → present its outcome and map it to an exit
  status. Branching policy, defaults, thresholds, error classification, and storage mutation belong in the Kit.
- One `package struct <UseCase>Runner: Sendable` per use case (`RunGoalRunner`, `DoctorRunner`, `ConfigRunner`).
  - Stored dependencies are `private let x: any P`; the initializer takes `some P` with the live implementation as
    the default argument.
  - `func run(...) async throws -> <Outcome>` returns a value. The Runner does not print. Progress that must stream is reported through an
    injected reporter closure or protocol.
  - Finite outcomes, modes, and error classes are `enum`s.
- Frontends other than the CLI (JSON, MCP, tests) call the same Runner; they may encode results but never duplicate
  use-case logic.

## Side effects behind protocols

- **Processes**: use `swiftlang/swift-subprocess` through `Ryu0118/ProcessRunning` (`ProcessRunning` /
  `ProcessRunner`), or a small domain protocol on top of it. Never use `Foundation.Process`. Replacing the current
  process (`execv`) is a CLI-layer adapter.
- **File system**: use `Ryu0118/FileManagerProtocol` (`any FileManagerProtocol`, default `FileManager.default`).
  Kit code never calls `FileManager.default`, `Data(contentsOf:)`, or `.write(to:)` directly.
- **Environment and home directory**: read `ProcessInfo` in one place (the composition root or one resolver type) and
  pass values in. Never read environment variables deep inside the Kit.
- **Output**: go through an injectable output type (closures for stdout / stderr with a `live` value), not bare
  `print` / `FileHandle`. Data goes to stdout, progress and diagnostics to stderr.
- **Network**: behind a protocol with a stub for tests (e.g. swift-jev's `JevTransport`).
- Name capability protocols with `-ing` / `-able` (`ProcessRunning`, `DeviceDriving`, `StepPlanning`); name live
  implementations `Live*` / `Posix*` when the name would otherwise be ambiguous.
- Injection is by initializer only. No global mutable state, no service locators, no `@Dependency`.

## Errors and exit codes

- Errors are `enum <Domain>Error: Error, Equatable, Sendable, CustomStringConvertible`, one per file, with messages
  that say what went wrong and how to fix it.
- Never swallow an error after printing it: rethrow or `throw ExitCode(...)`.
- Exit statuses: 0 success, 64 invalid arguments (ArgumentParser), others defined once in the CLI target. A wrapped
  child process's status passes through unchanged.

## Tests

The policy is the Testing section of `CLAUDE.md`: end-to-end cases first (`mise run e2e`), isolated tests only for
enumerable failure modes, written as that list before the code.

- Isolated Kit tests inject fakes (`Fake*`, `Recording*`, `Failing*`, `Stub*`) through the initializer. A command's
  output and exit status are checked end to end; the CLI test target covers argument parsing only.
- Unit tests do not use the network or the developer's home directory; file-system tests use a temporary directory.
- Anything that needs a real external tool (a simulator, `sim-use`, a live API) is an integration or contract test in
  its own clearly named target or task (`mise run contract-test`, `scripts/e2e-simulator.sh`), not part of the default
  unit run.
