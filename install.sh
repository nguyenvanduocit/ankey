#!/bin/sh
# Install the latest Ankey release into ~/Library/Input Methods.
#   curl -fsSL https://raw.githubusercontent.com/nguyenvanduocit/ankey/main/install.sh | sh
# Checks the SHA-256 against the published checksum, then the Developer ID signature and bundle ID,
# before anything replaces the installed app.
set -eu

REPO="nguyenvanduocit/ankey"
TEAM_ID="694MCRBCD6"
BUNDLE_ID="dev.firegroup.inputmethod.Ankey"
DEST="$HOME/Library/Input Methods/Ankey.app"

fail() { echo "install: $1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Ankey runs on macOS only"
[ "$(uname -m)" = "arm64" ] || fail "Ankey needs Apple silicon"
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || fail "Ankey needs macOS 13 or later"

# /releases/latest redirects to /releases/tag/vX.Y.Z. This avoids the API rate limit.
LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
TAG="${LATEST_URL##*/}"
VERSION="${TAG#v}"
case "$VERSION" in
    '' | *[!0-9.]*) fail "could not read the latest version from $LATEST_URL" ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ZIP="Ankey-$VERSION.zip"
BASE="https://github.com/$REPO/releases/download/$TAG"

echo "Downloading Ankey $VERSION"
curl -fsSL -o "$WORK/$ZIP" "$BASE/$ZIP"
curl -fsSL -o "$WORK/$ZIP.sha256" "$BASE/$ZIP.sha256"

EXPECTED="$(cut -d' ' -f1 "$WORK/$ZIP.sha256")"
ACTUAL="$(shasum -a 256 "$WORK/$ZIP" | cut -d' ' -f1)"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || fail "checksum mismatch, nothing installed"

ditto -x -k "$WORK/$ZIP" "$WORK/extracted"
APP="$WORK/extracted/Ankey.app"
codesign --verify --deep --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\"" "$APP" \
    || fail "signature is not Developer ID team $TEAM_ID, nothing installed"
FOUND_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
FOUND_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ "$FOUND_ID" = "$BUNDLE_ID" ] && [ "$FOUND_VERSION" = "$VERSION" ] || fail "unexpected app in the download, nothing installed"

mkdir -p "$(dirname "$DEST")"
UPGRADE=0
[ -d "$DEST" ] && UPGRADE=1
rm -rf "$DEST"
ditto "$APP" "$DEST"
echo "Installed $DEST"

if [ "$UPGRADE" = 1 ]; then
    # macOS starts Ankey again from the new copy the next time a text field needs it.
    pkill -x Ankey 2>/dev/null || true
    echo "Ankey $VERSION is ready. Switch input sources once to load it."
else
    cat <<'EOF'

Next steps:
  1. Log out and back in. macOS lists a new input method only after that.
  2. System Settings -> Keyboard -> Input Sources -> Edit... -> + -> Vietnamese -> Ankey.
  3. Switch to Ankey from the input-source menu in the menu bar.
EOF
fi
