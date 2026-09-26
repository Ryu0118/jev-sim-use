# Development Workflow Rules

## Commits

- Keep commits small and easy to revert: one logical change per commit.
- gitnagg (`.gitnagg.yml`) checks the uncommitted diff after every agent edit; the first matching tier wins:
  - **error** at 200+ added lines or 6+ changed files: stop and split the change into smaller commits before continuing.
  - **warning** at 120+ added lines or 3+ changed files: good checkpoint, commit now.
  - **info** at 80+ added lines: there is enough local change to justify a checkpoint commit.
- Re-run `mise run build`, `mise run test`, `mise run lint`, and `mise run ast-lint` after every content-changing commit, not only at the end. `mise run check` runs format, lint, AST lint, build, test, and docsync in one go.
- Do a directory move as a pure `git mv` in its own commit, before any content edits.

## Git Hooks

Install with `mise run setup` (or `mise run setup-hooks`), which sets `core.hooksPath=.githooks`.

`pre-commit` runs, in this order, and any failure blocks the commit:

1. **gitleaks** `protect --staged` scans the staged diff for secrets (skipped with a notice if gitleaks is not installed).
2. **SwiftFormat** formats the staged Swift files and re-stages them.
3. **SwiftLint** `--strict` lints the staged Swift files.
4. **my-swift-linter** lints `Sources` and `Tests` with `.my-swift-linter.yml`.
5. **docsync** `check` verifies that tracked docs are in sync with their sources.

Steps 2-4 run only when Swift files are staged; gitleaks and docsync always run.

`pre-push` runs the AST lint (`mise run ast-lint`) over the whole package.

## Agent Hooks

Claude Code (`.claude/settings.json`) and Codex (`.codex/hooks.json`) run the same shared scripts in `scripts/`:

- Before `git commit`: the pre-commit checks above except gitleaks (format and SwiftLint on the staged files, AST lint on the whole package, docsync); a failure blocks the commit.
- After every edit of a Swift file: SwiftFormat, then SwiftLint and my-swift-linter on that file; violations are reported back to the agent.
- After every edit: gitnagg checks the diff size.

## Documentation Sync

- `docsync.yml` ties docs to the sources they describe. Editing or moving a tracked source invalidates its checksum.
- After changing a tracked source, review the linked doc, update it if needed, then run `mise run update-docsync-checksum`. `mise run docsync-check` must pass before commit.
- When you add a doc that describes code or config, add a rule for it to `docsync.yml`.

## CI

- `.github/workflows/test.yml`: SwiftFormat `--lint`, SwiftLint `--strict`, and AST lint, then build and test.
- `.github/workflows/docsync-check.yml`: `docsync check`.
- `.github/workflows/gitleaks.yml`: secret scan of the full history on every push and pull request.
