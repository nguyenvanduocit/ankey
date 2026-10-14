#!/bin/sh
# Publish an Ankey release: ./release.sh 1.1.0
# Needs a clean git tree with an origin remote, a Developer ID certificate, an authenticated
# gh CLI, and a notarytool keychain profile (NOTARY_PROFILE, default ankey-notary):
#   xcrun notarytool store-credentials ankey-notary --apple-id <id> --team-id REDACTED
set -eu

cd "$(dirname "$0")"
VERSION="${1:?usage: ./release.sh X.Y.Z}"
TAG="v$VERSION"
PROFILE="${NOTARY_PROFILE:-ankey-notary}"
PLIST="Info.plist"
ZIP="Ankey-$VERSION.zip"

fail() { echo "release: $1" >&2; exit 1; }

case "$VERSION" in
    *[!0-9.]* | .* | *. | *..*) fail "version must look like 1.2.3" ;;
esac
git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository"
git remote get-url origin >/dev/null 2>&1 || fail "no origin remote"
[ -z "$(git status --porcelain)" ] || fail "working tree is not clean"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "tag $TAG already exists"
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || fail "notarytool profile '$PROFILE' not found"

CURRENT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
NEWEST="$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)"
[ "$NEWEST" = "$VERSION" ] && [ "$CURRENT" != "$VERSION" ] || fail "$VERSION is not newer than $CURRENT"

BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((BUILD + 1))" "$PLIST"

REQUIRE_DEVELOPER_ID=1 ./build.sh
cd dist
rm -f Ankey-*.zip Ankey-*.zip.sha256

ditto -c -k --keepParent Ankey.app "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait | tee /tmp/ankey-notary.log
grep -q "status: Accepted" /tmp/ankey-notary.log || fail "notarization was not accepted"
xcrun stapler staple Ankey.app
spctl --assess --type execute -vv Ankey.app 2>&1 | grep -q "Notarized Developer ID" \
    || fail "Gatekeeper does not accept the stapled app"

rm "$ZIP"
ditto -c -k --keepParent Ankey.app "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
cd ..

git add "$PLIST"
git commit -m "Release $VERSION"
git push origin HEAD
gh release create "$TAG" "dist/$ZIP" "dist/$ZIP.sha256" \
    --target "$(git rev-parse HEAD)" --title "Ankey $VERSION" --generate-notes
git fetch --tags
echo "released $TAG"
