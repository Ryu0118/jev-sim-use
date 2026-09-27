#!/bin/bash
# Sets every file that carries the release version to $1: the binary's version, the skill's (its frontmatter and the
# `--version` check it asks for), and the plugin and package manifests. The release workflow runs it twice: in the
# build job, so the binary and the skill it embeds carry the new number, and in the job that commits the bump.
# perl, not sed: the jobs run on macOS and Linux, whose `sed -i` differ.
set -euo pipefail

version=${1:?usage: scripts/bump-version.sh <version>}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must be x.y.z, got \"$version\"" >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Replaces `pattern` (with the old version in a capture group's place) in `file`, and fails if nothing matched.
replace() {
    local file=$1 pattern=$2 replacement=$3
    V="$version" perl -0pi -e "s/$pattern/$replacement/g or die qq(no match in $file\n)" "$file"
}

replace Sources/JevSimUseKit/Version.swift 'package static let current = "[^"]*"' 'package static let current = "$ENV{V}"'
replace skills/jev-sim-use/SKILL.md '\n  version: "[^"]*"\n' '\n  version: "$ENV{V}"\n'
replace skills/jev-sim-use/SKILL.md '# must be [0-9][^,]*,' '# must be $ENV{V},'
replace apm.yml '\nversion: [^\n]*' '\nversion: $ENV{V}'
# Each of these files has exactly one "version" key.
for file in .claude-plugin/marketplace.json .claude/plugins/jev-sim-use/.claude-plugin/plugin.json \
    plugins/jev-sim-use/.codex-plugin/plugin.json; do
    replace "$file" '"version": "[^"]*"' '"version": "$ENV{V}"'
done
