# Swift Coding Rules

Rules for writing Swift in SimJevUse. Lint-enforced details live in `lint-and-format.md`; this file covers design and conventions that the linters cannot fully check.

## Architecture

- `Sources/SimJevUse/` is the entry point only. It parses the process arguments and calls into `SimJevUseKit`; it holds no business logic.
- `Sources/SimJevUseKit/` holds **all implementation**. Anything worth testing lives here.
- `Tests/SimJevUseKitTests/` holds the unit tests for the Kit target.
- SwiftPM discovers sources recursively, so moving files between subdirectories needs no `Package.swift` change.
- Group 2-3 or more related files per subdirectory. Do not create a directory for a single file, and do not turn the module root into nothing but directories: keep the entry-point type and single-file concerns at the module root.

## Access Control

- Use `package` for any declaration that another module in this package (the executable target, the test target) needs. Do not use `public` unless the symbol is part of a library product consumed outside this package.
- Default to `internal` (no modifier) inside a module, and `private` / `fileprivate` for implementation details.
- Widening access (`private` → `internal` / `package`) to allow a file split is fine, as long as no `public` signature changes.
- Tests reach `internal` symbols through `@testable import`; do not widen access just for tests.

## Comments and Documentation

- Comment the "why", not the "what". Add a comment only where the logic has a non-obvious invariant or encodes an external spec (a file format, a CLI contract, an OS quirk). Do not comment self-explanatory code.
- Every `package` or `public` declaration in `SimJevUseKit` needs a `///` doc comment (enforced by the `missing-docs` AST lint rule). Initializers, `CodingKeys`, `errorDescription`, `==`, and result-builder / string-interpolation hooks are exempt.

## Abstraction

- Do not extract abstractions from code that only looks similar. Before factoring out a shared helper, check what is actually identical across call sites. If the guard condition, the non-shared branch, and the return shape all differ, leave the near-duplicates alone; only extract when the shared part is substantial.
- Free functions are not allowed at file scope (`no-top-level-function`). Put helpers on a type, in an extension, or in a caseless namespace `enum`.

## Concurrency

- The package builds in Swift 6 language mode with complete strict concurrency checking. Code must compile with no data-race diagnostics.
- Never use `@unchecked Sendable` to silence the compiler. Fix the isolation instead.
- Shared mutable state goes in an `actor`. Value types and immutable classes conform to `Sendable` normally.
- Protocols whose conformers cross concurrency domains are declared `Sendable` (for example `protocol GitCloning: Sendable`).

## Errors

- Domain errors are `enum`s (or structs) conforming to `LocalizedError`, with an `errorDescription` that tells the user what went wrong and, where possible, how to fix it.
- Throw typed domain errors from `SimJevUseKit`; the executable target only catches, prints `localizedDescription`, and sets the exit code.

## Dependency Injection

- Side effects (running processes, file system access, network, clocks, environment variables) sit behind a protocol: a `ProcessRunning` protocol for subprocesses and a `FileManagerProtocol` for the file system (add them as package dependencies or define them in the Kit; neither ships with the template), and small capability protocols of your own (named with an `-ing` suffix, e.g. `GitCloning`, `DirectoryWatching`).
- Types store dependencies as `private let x: any Protocol` and take them through the initializer as `some Protocol`, with the live implementation as the default argument (`processRunner: some ProcessRunning = ProcessRunner()`).
- Tests supply hand-written fakes or mocks that record calls and return canned results. No mocking frameworks.

## Testing

- Use Swift Testing only (`import Testing`, `@Test`, `@Suite`, `#expect`, `#require`). Do not use XCTest.
- Import the module under test with `@testable import SimJevUseKit`.
- Test functions use lowerCamelCase names, never a `test` prefix, underscores, or backtick phrases. Put the human-readable sentence in `@Test("…")`, and make it add information beyond the function name. `@Suite` descriptions must describe behavior, not repeat the type name.
- Unit tests never touch the real network, spawn real processes, or depend on the developer's home directory. Inject fakes, and use a temporary directory for file-system tests.
- Put test fixture files under a `Fixtures/` directory; the AST linter skips it.
