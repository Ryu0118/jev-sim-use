# Code Review Checklist

Apply these when reviewing or refactoring code in this repository.

- **Directory splits stay behavior-neutral.** Do a pure `git mv` in its own commit before any content edit, so git records clean renames and bisect/revert stays possible. Confirm SwiftPM still builds with no `Package.swift` change (it discovers sources recursively).
- **No lone-file directories, no all-directory root.** Group 2-3 or more related files per subdirectory. Keep the entry point and single-file concerns at the module root rather than moving each into a directory of one.
- **Comment the "why", not the "what".** Add comments only where the logic has a non-obvious invariant or encodes an external spec. Skip comments on self-explanatory code.
- **Don't extract abstractions from superficially similar code.** Before factoring out a shared helper, check what is actually identical across call sites and what only looks similar. If the guard condition, the non-shared branch, and the return shape all differ, the "dedup" adds an awkward helper for almost no saved lines. Leave near-duplicates alone unless the shared part is substantial.
- **Widening access (`private` → `internal` / `package`) to enable a file split is fine**, as long as no `public` signature changes.
- **Re-run `mise run build`, `mise run test`, `mise run lint`, and `mise run ast-lint` after every content-changing commit**, not just at the end. The pre-commit hook (`swiftlint --strict` + my-swift-linter) hard-blocks a bad commit, and drift is cheaper to catch right away.
- **Check `docsync.yml` after moving or editing any file it tracks** (`mise run docsync-check` / `mise run update-docsync-checksum`). Moving a tracked path or editing a tracked file invalidates its checksum, and the pre-commit hook fails the commit until the docs are resynced.
- **Clean up untracked cruft found along the way** (for example a stray `.DS_Store`) in the same pass, even if it is unrelated to the main task.
