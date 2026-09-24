#!/bin/sh
SOURCE_ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 0
exec "$SOURCE_ROOT/scripts/agent-pre-commit-lint.sh"
