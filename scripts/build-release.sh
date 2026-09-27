#!/bin/bash
# Builds the universal (arm64 + x86_64) release binary the way the release workflow ships it, checks both slices,
# and leaves it at .build/apple/Products/Release/jev-sim-use. The release workflow and CI both run this script.
#
# `--build-system swiftbuild`: with Swift 6.3's default build system, a multi-arch build fails to resolve the
# EmbedSkill build tool plugin ("a reference to a missing target with GUID 'PACKAGE-TARGET:EmbedSkill@…'").
# swiftbuild writes to .build/out, but github-action-artifactbundle only looks in .build/apple/Products/Release (or
# per-triple directories), so the binary is copied there.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c release --arch arm64 --arch x86_64 --build-system swiftbuild

built=.build/out/Products/Release/jev-sim-use
archs=$(lipo -archs "$built")
for arch in arm64 x86_64; do
    if [[ " $archs " != *" $arch "* ]]; then
        echo "error: $built has architectures \"$archs\"; $arch is missing" >&2
        exit 1
    fi
done

staged=.build/apple/Products/Release
mkdir -p "$staged"
cp "$built" "$staged/jev-sim-use"
echo "$staged/jev-sim-use ($archs)"
