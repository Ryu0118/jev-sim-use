#!/bin/sh
set -eu

SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$SOURCE_ROOT" ]; then
    echo "Skipping Git hook setup: not inside a Git repository."
    exit 0
fi

HOOKS_DIR="$SOURCE_ROOT/.githooks"
if [ ! -d "$HOOKS_DIR" ]; then
    echo "Shared hooks directory not found: $HOOKS_DIR" >&2
    exit 1
fi

git -C "$SOURCE_ROOT" config --local core.hooksPath .githooks
chmod +x "$HOOKS_DIR/pre-commit"
echo "Configured Git hooks: $HOOKS_DIR"
