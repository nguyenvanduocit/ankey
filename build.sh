#!/bin/sh
# Build and sign dist/Ankey.app after the engine tests pass.
#   ./build.sh            build only
#   ./build.sh --install  also install into ~/Library/Input Methods and restart the running Ankey
# SIGN_IDENTITY=<hash or name> overrides the signing identity; TEAM_ID=<team> picks the team's Developer ID.
# REQUIRE_DEVELOPER_ID=1 fails instead of falling back to an ad-hoc signature.
set -eu

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP="$ROOT/dist/Ankey.app"

swiftc -swift-version 5 -target arm64-apple-macosx13.0 \
    -o /tmp/ankey-tests \
    "$ROOT"/Core/*.swift "$ROOT"/Tests/*.swift
/tmp/ankey-tests

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# The phrase list is packed into the index Ankey maps at run time.
swiftc -swift-version 5 -target arm64-apple-macosx13.0 \
    -o /tmp/ankey-mkphrases \
    "$ROOT"/Core/*.swift "$ROOT"/tools/mkphrases/main.swift
/tmp/ankey-mkphrases "$ROOT/Resources/phrases.txt" "$APP/Contents/Resources/phrases.idx"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/Ankey.tiff" "$ROOT/Resources/AppIcon.icns" "$ROOT/Resources/VT323-Regular.ttf" "$ROOT/Resources/VT323-OFL.txt" "$ROOT/Resources/ai-guide.md" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

swiftc -swift-version 5 -strict-concurrency=complete -O -target arm64-apple-macosx13.0 \
    -framework Cocoa -framework InputMethodKit -framework Carbon -framework SwiftUI -framework Security \
    -o "$APP/Contents/MacOS/Ankey" \
    "$ROOT"/Core/*.swift "$ROOT"/App/*.swift

# SIGN_IDENTITY picks the signing identity. Without it, the Developer ID Application identity of
# TEAM_ID (environment or .env) signs the app; with no TEAM_ID, the first one in the keychain does.
TEAM_ID="${TEAM_ID:-$(sed -n 's/^TEAM_ID=//p' .env 2>/dev/null | head -1)}"
SIGN_ID="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -v team="$TEAM_ID" '/Developer ID Application/ && (team == "" || index($0, "(" team ")")) { print $2; exit }')}"
sign() {
    if [ -n "$SIGN_ID" ] && codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$1"; then
        return
    fi
    if [ "${REQUIRE_DEVELOPER_ID:-0}" = 1 ]; then
        echo "Developer ID signing failed." >&2
        exit 1
    fi
    echo "Developer ID identity unavailable. Ad-hoc signature." >&2
    codesign --force --sign - "$1"
}
sign "$APP"
echo "built $APP"

if [ "${1:-}" = "--install" ]; then
    DEST="$HOME/Library/Input Methods/Ankey.app"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
    sign "$DEST"
    echo "installed $DEST"
    # macOS starts Ankey again from the installed copy the next time a text field needs it.
    pkill -x Ankey 2>/dev/null || true
fi
