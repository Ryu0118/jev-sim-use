#!/bin/sh
set -eu

HOOK_INPUT=$(cat)
SOURCE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$SOURCE_ROOT/.gitnagg.yml" ] || exit 0

GITNAGG=$("$SOURCE_ROOT/scripts/mise.sh" which gitnagg 2>/dev/null || true)
[ -x "$GITNAGG" ] || exit 0

printf '%s' "$HOOK_INPUT" | "$GITNAGG" check --config "$SOURCE_ROOT/.gitnagg.yml" --claude-hook
