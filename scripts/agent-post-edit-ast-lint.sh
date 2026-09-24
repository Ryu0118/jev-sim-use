#!/bin/sh
set -eu

HOOK_INPUT=$(cat)
FILE_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
case "$FILE_PATH" in
    *.swift) ;;
    *) exit 0 ;;
esac

SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
case "$FILE_PATH" in
    /*) TARGET_FILE="$FILE_PATH" ;;
    *) TARGET_FILE="$SOURCE_ROOT/$FILE_PATH" ;;
esac
[ -f "$TARGET_FILE" ] || exit 0

MY_SWIFT_LINTER=$("$SOURCE_ROOT/scripts/mise.sh" which my-swift-linter 2>/dev/null || true)
[ -x "$MY_SWIFT_LINTER" ] || exit 0

set +e
LINT_OUTPUT=$("$MY_SWIFT_LINTER" "$TARGET_FILE" 2>&1)
LINT_EXIT=$?
set -e

[ "$LINT_EXIT" -eq 0 ] && exit 0
[ -n "$LINT_OUTPUT" ] || exit 0

jq -n --arg reason "$LINT_OUTPUT" '{"decision":"block","reason":$reason}'
