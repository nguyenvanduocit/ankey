#!/bin/sh
# Build and sign dist/Ankey.app after the engine tests pass.
#   ./build.sh            build only
#   ./build.sh --install  also install into ~/Library/Input Methods
# SIGN_IDENTITY=<hash or name> overrides the signing identity.
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
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/Ankey.tiff" "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 \
    -framework Cocoa -framework InputMethodKit -framework Carbon -framework SwiftUI -framework Security \
    -o "$APP/Contents/MacOS/Ankey" \
    "$ROOT"/Core/*.swift "$ROOT"/App/*.swift

# SIGN_IDENTITY picks the signing identity. Without it, the first Developer ID Application
# identity in the keychain signs the app.
SIGN_ID="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ { print $2; exit }')}"
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
    pkill -x Ankey 2>/dev/null || true
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
    sign "$DEST"
    echo "installed $DEST"
fi
