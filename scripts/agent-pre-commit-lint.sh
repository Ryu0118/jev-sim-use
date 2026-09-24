#!/bin/sh
set -eu

HOOK_INPUT=$(cat)
COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
case "$COMMAND" in
    git\ commit*) ;;
    *) exit 0 ;;
esac

SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)

set +e
CHECK_OUTPUT=$("$SOURCE_ROOT/scripts/lint-staged.sh" 2>&1)
CHECK_EXIT=$?
set -e

[ "$CHECK_EXIT" -eq 0 ] && exit 0
jq -n --arg reason "$CHECK_OUTPUT" '{"decision":"block","reason":$reason}'
