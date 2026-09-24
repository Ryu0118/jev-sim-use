# Swift Coding Rules

Language-level conventions for JevSimUse. Architecture, layering, Runners, dependency injection, and the SSoT / DRY / SOLID principles live in `coding-rules.md`; lint-enforced details in `lint-and-format.md`.

## Files and directories

- One concern per file; extensions go in `Type+Concern.swift`.
- Group 2-3 or more related files per subdirectory. Do not create a directory for a single file, and do not turn the module root into nothing but directories.
- SwiftPM discovers sources recursively, so moving files between subdirectories needs no `Package.swift` change. Do pure moves with `git mv` in their own behavior-neutral commit.

## Access Control

- Use `package` for any declaration that another module in this package (the executable target, the test target) needs. Do not use `public` unless the symbol is part of a library product consumed outside this package.
- Default to `internal` (no modifier) inside a module, and `private` / `fileprivate` for implementation details.
- Widening access (`private` → `internal` / `package`) to allow a file split is fine, as long as no `public` signature changes.
- Tests reach `internal` symbols through `@testable import`; do not widen access just for tests.

## Comments and Documentation

- Comment the "why", not the "what". Add a comment only where the logic has a non-obvious invariant or encodes an external spec (a file format, a CLI contract, an OS quirk). Do not comment self-explanatory code.
- Every `package` or `public` declaration in `JevSimUseKit` needs a `///` doc comment (enforced by the `missing-docs` AST lint rule). Initializers, `CodingKeys`, `errorDescription`, `==`, and result-builder / string-interpolation hooks are exempt.

## Abstraction

- Do not extract abstractions from code that only looks similar. Before factoring out a shared helper, check what is actually identical across call sites. If the guard condition, the non-shared branch, and the return shape all differ, leave the near-duplicates alone; only extract when the shared part is substantial.
- Free functions are not allowed at file scope (`no-top-level-function`). Put helpers on a type, in an extension, or in a caseless namespace `enum`.
- Use an `enum` namespace only for stateless pure helpers or process-wide constants; use a `struct` when operations share configuration or a dependency; use an `actor` only for mutable state shared across concurrent tasks.

## Concurrency

- The package builds in Swift 6 language mode with complete strict concurrency checking. Code must compile with no data-race diagnostics.
- Do not use `@unchecked Sendable` to silence the compiler; fix the isolation. If it is genuinely required (e.g. wrapping a non-Sendable system handle), keep it minimal and add a `//` rationale. Treat `try?` and cleanup races the same way.
- Use `Mutex` (Synchronization) for small locked state that does not warrant an actor.
- Shared mutable state goes in an `actor`. Value types and immutable classes conform to `Sendable` normally.
- Protocols whose conformers cross concurrency domains are declared `Sendable` (for example `protocol GitCloning: Sendable`).

## Errors

- See `coding-rules.md` (`Error, Equatable, Sendable, CustomStringConvertible` enums, never swallowed).

## Testing

- Use Swift Testing only (`import Testing`, `@Test`, `@Suite`, `#expect`, `#require`). Do not use XCTest.
- Import the module under test with `@testable import JevSimUseKit`.
- Test functions use lowerCamelCase names, never a `test` prefix, underscores, or backtick phrases. Put the human-readable sentence in `@Test("…")`, and make it add information beyond the function name. `@Suite` descriptions must describe behavior, not repeat the type name.
- Unit tests never touch the real network or depend on the developer's home directory. Inject fakes, and use a temporary directory for file-system tests. Tests that need real external tools belong in integration / contract tests (see `coding-rules.md`).
- Parameterize with `@Test(arguments:)` instead of copy-pasted tests.
- All identifiers, comments, test names, and diagnostics are in English.
- Put test fixture files under a `Fixtures/` directory; the AST linter skips it.
