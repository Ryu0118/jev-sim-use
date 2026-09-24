#!/bin/sh
set -eu

SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
STAGED_SWIFT_FILES=$(git -C "$SOURCE_ROOT" diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
[ -n "$STAGED_SWIFT_FILES" ] || exit 0

SWIFTFORMAT=$("$SOURCE_ROOT/scripts/mise.sh" which swiftformat 2>/dev/null || true)
SWIFTLINT=$("$SOURCE_ROOT/scripts/mise.sh" which swiftlint 2>/dev/null || true)
MY_SWIFT_LINTER=$("$SOURCE_ROOT/scripts/mise.sh" which my-swift-linter 2>/dev/null || true)
DOCSYNC=$("$SOURCE_ROOT/scripts/mise.sh" which docsync 2>/dev/null || true)

if [ ! -x "$SWIFTFORMAT" ] || [ ! -x "$SWIFTLINT" ] || [ ! -x "$MY_SWIFT_LINTER" ] || [ ! -x "$DOCSYNC" ]; then
    echo "SwiftFormat, SwiftLint, my-swift-linter, and docsync are required. Run: mise run setup" >&2
    exit 1
fi

while IFS= read -r file; do
    [ -n "$file" ] || continue
    "$SWIFTFORMAT" --config "$SOURCE_ROOT/.swiftformat" "$SOURCE_ROOT/$file"
    git -C "$SOURCE_ROOT" add -- "$file"
    "$MY_SWIFT_LINTER" "$SOURCE_ROOT/$file"
done <<EOF
$STAGED_SWIFT_FILES
EOF

LINT_OUTPUT_FILE=$(mktemp)
trap 'rm -f "$LINT_OUTPUT_FILE"' EXIT HUP INT TERM
LINT_FAILED=0

while IFS= read -r file; do
    [ -n "$file" ] || continue
    if ! OUTPUT=$("$SWIFTLINT" lint --config "$SOURCE_ROOT/.swiftlint.yml" --force-exclude --strict --quiet "$SOURCE_ROOT/$file" 2>&1); then
        printf '%s:\n%s\n\n' "$file" "$OUTPUT" >>"$LINT_OUTPUT_FILE"
        LINT_FAILED=1
    fi
done <<EOF
$STAGED_SWIFT_FILES
EOF

if [ "$LINT_FAILED" -ne 0 ]; then
    cat "$LINT_OUTPUT_FILE" >&2
    exit 1
fi

"$DOCSYNC" check --config "$SOURCE_ROOT/docsync.yml"
