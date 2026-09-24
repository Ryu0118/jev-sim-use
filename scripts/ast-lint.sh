#!/bin/bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARY=$("$SOURCE_ROOT/scripts/mise.sh" which my-swift-linter 2>/dev/null || true)

if [ -z "$BINARY" ] || [ ! -x "$BINARY" ]; then
    echo "my-swift-linter not found. Run: mise run setup" >&2
    exit 1
fi

FIX_FLAG=""
if [ "${1:-}" = "--fix" ]; then
    FIX_FLAG="--fix"
    shift
fi

if [ "${1:-}" = "--staged" ]; then
    FILES=$(git -C "$SOURCE_ROOT" diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
    [ -z "$FILES" ] && exit 0
    LINT_ARGS=()
    while IFS= read -r file; do
        LINT_ARGS+=("$SOURCE_ROOT/$file")
    done <<< "$FILES"
elif [ "${1:-}" = "--changed" ]; then
    FILES=$(git -C "$SOURCE_ROOT" diff --name-only --diff-filter=ACM HEAD | grep '\.swift$' || true)
    [ -z "$FILES" ] && exit 0
    LINT_ARGS=()
    while IFS= read -r file; do
        LINT_ARGS+=("$SOURCE_ROOT/$file")
    done <<< "$FILES"
elif [ "$#" -gt 0 ]; then
    LINT_ARGS=("$@")
else
    LINT_ARGS=("$SOURCE_ROOT/Sources" "$SOURCE_ROOT/Tests")
fi

if [ -n "$FIX_FLAG" ]; then
    exec "$BINARY" "$FIX_FLAG" "${LINT_ARGS[@]}"
else
    exec "$BINARY" "${LINT_ARGS[@]}"
fi
