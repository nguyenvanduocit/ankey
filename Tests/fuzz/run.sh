#!/bin/sh
# Ask Jev which English words the engine still converts to Vietnamese.
#   AI_GATEWAY_API_KEY=... ./Tests/fuzz/run.sh [sample-size, default 20000]
# Not part of build.sh: the answers come from a model, so they are leads to review by hand.
# A confirmed lead becomes a row in Core/English.swift and a check() in Tests/TestMain.swift.
set -eu

cd "$(dirname "$0")/../.."
SAMPLE="${1:-20000}"

swiftc -swift-version 5 -target arm64-apple-macosx13.0 \
    -o /tmp/ankey-fuzz Core/*.swift Tests/fuzz/main.swift

[ -d Tests/fuzz/node_modules ] || (cd Tests/fuzz && bun install --silent)

# Lowercase ASCII words of 3 to 8 letters from the system word list; the ones Telex leaves alone are dropped.
grep -E '^[a-z]{3,8}$' /usr/share/dict/words | sort -R | head -n "$SAMPLE" \
    | /tmp/ankey-fuzz | bun Tests/fuzz/judge.mjs
