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
        LINT_ARGS+=("$file")
    done <<< "$FILES"
elif [ "${1:-}" = "--changed" ]; then
    FILES=$(git -C "$SOURCE_ROOT" diff --name-only --diff-filter=ACM HEAD | grep '\.swift$' || true)
    [ -z "$FILES" ] && exit 0
    LINT_ARGS=()
    while IFS= read -r file; do
        LINT_ARGS+=("$file")
    done <<< "$FILES"
elif [ "$#" -gt 0 ]; then
    LINT_ARGS=("$@")
else
    LINT_ARGS=(Sources Tests Package.swift)
fi

# Include globs in .swift-ast-lint.yml are relative to the package root.
cd "$SOURCE_ROOT"
if [ -n "$FIX_FLAG" ]; then
    exec "$BINARY" --config "$SOURCE_ROOT/.swift-ast-lint.yml" --no-cache "$FIX_FLAG" "${LINT_ARGS[@]}"
else
    exec "$BINARY" --config "$SOURCE_ROOT/.swift-ast-lint.yml" --no-cache "${LINT_ARGS[@]}"
fi
