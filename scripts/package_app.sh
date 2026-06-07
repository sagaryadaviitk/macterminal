#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-debug}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BINARY_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_DIR="$BINARY_DIR/MacTerminal.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

install -m 755 "$BINARY_DIR/MacTerminal" "$MACOS_DIR/MacTerminal"
install -m 644 "$ROOT_DIR/Sources/MacTerminal/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -f "$ROOT_DIR/Resources/MacTerminal.icns" ]]; then
  install -m 644 "$ROOT_DIR/Resources/MacTerminal.icns" "$RESOURCES_DIR/MacTerminal.icns"
fi
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
