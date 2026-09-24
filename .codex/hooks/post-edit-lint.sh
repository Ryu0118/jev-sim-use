#!/bin/sh
SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
exec "$SOURCE_ROOT/scripts/agent-post-edit-lint.sh"
