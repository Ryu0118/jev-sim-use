# SimJevUse

Swift executable package with a small Kit target and Swift Testing.

## Development workflow

- `mise run setup` — install tools, configure Git hooks
- `mise run check` — format, lint, build, test, docsync
- `mise run test` — run the test suite
- See `.mise.toml` for the full task list (`mise tasks`)
- Git hooks in `.githooks/` enforce format + lint on staged changes
- Keep commits small and easy to revert

## Code standards

- Keep business logic in `SimJevUseKit` (testable); executable entry point stays thin
- Swift 6 strict-concurrency compatible; default to package-internal access, `public` only when
  another module needs the symbol
- Doc comments required for non-obvious public APIs and compatibility constraints
