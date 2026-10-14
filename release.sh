#!/bin/sh
# Start a release: ./release.sh 1.1.0
# Bumps Info.plist, commits, tags vX.Y.Z and pushes. GitHub Actions
# (.github/workflows/release.yml) builds, notarizes and publishes from the tag.
set -eu

cd "$(dirname "$0")"
VERSION="${1:?usage: ./release.sh X.Y.Z}"
TAG="v$VERSION"
PLIST="Info.plist"

fail() { echo "release: $1" >&2; exit 1; }

case "$VERSION" in
    *[!0-9.]* | .* | *. | *..*) fail "version must look like 1.2.3" ;;
esac
git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository"
git remote get-url origin >/dev/null 2>&1 || fail "no origin remote"
[ -z "$(git status --porcelain)" ] || fail "working tree is not clean"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "tag $TAG already exists"

CURRENT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
NEWEST="$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)"
[ "$NEWEST" = "$VERSION" ] && [ "$CURRENT" != "$VERSION" ] || fail "$VERSION is not newer than $CURRENT"

BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((BUILD + 1))" "$PLIST"

git add "$PLIST"
git commit -m "Release $VERSION"
git tag "$TAG"
git push origin HEAD "$TAG"
echo "pushed $TAG. Follow the build: gh run watch"
