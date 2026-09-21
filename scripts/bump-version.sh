#!/usr/bin/env bash
# Prepare a release: set MARKETING_VERSION, cut the CHANGELOG section, regenerate
# the Xcode project. CURRENT_PROJECT_VERSION is left alone: Xcode Cloud assigns
# build numbers itself. Commit + PR + tag are manual;
# see ops/release-checklist.md.
#
#   scripts/bump-version.sh 1.2.0
set -euo pipefail

version="${1:?usage: $0 X.Y.Z}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not semver: $version" >&2; exit 1; }

cd "$(dirname "$0")/.."

grep -q "^## \[Unreleased\]" CHANGELOG.md || { echo "CHANGELOG.md has no [Unreleased] section" >&2; exit 1; }
grep -q "^## \[$version\]" CHANGELOG.md && { echo "CHANGELOG.md already has $version" >&2; exit 1; }

sed -i '' -E "s/^( *MARKETING_VERSION:) \"[^\"]*\"/\1 \"$version\"/" project.yml
xcodegen generate

perl -pi -e "s/^## \\[Unreleased\\]$/## [Unreleased]\\n\\n## [$version] - $(date +%F)/" CHANGELOG.md

echo "Bumped to $version. Now: edit the CHANGELOG entry, commit, PR, merge, then:"
echo "  git tag v$version && git push origin v$version"
