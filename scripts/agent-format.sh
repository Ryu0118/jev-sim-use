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

SWIFTFORMAT=$("$SOURCE_ROOT/scripts/mise.sh" which swiftformat 2>/dev/null || true)
[ -x "$SWIFTFORMAT" ] || exit 0

exec "$SWIFTFORMAT" --config "$SOURCE_ROOT/.swiftformat" "$TARGET_FILE"
