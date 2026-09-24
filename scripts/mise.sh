#!/bin/sh
set -eu

SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
MISE_BIN=$(command -v mise 2>/dev/null || true)

if [ -z "$MISE_BIN" ]; then
    echo "mise is required. Install it from https://mise.jdx.dev/" >&2
    exit 1
fi

if [ -f "$SOURCE_ROOT/.mise.toml" ]; then
    "$MISE_BIN" trust --yes "$SOURCE_ROOT" >/dev/null
fi

exec "$MISE_BIN" "$@"
