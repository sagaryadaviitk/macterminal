#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
  debug|release) ;;
  *) echo "Configuration must be debug or release" >&2; exit 1 ;;
esac
SWIFT_BUILD_ARGS=(-c "$CONFIGURATION")
if [[ -n "${MAC_TERMINAL_BUILD_SYSTEM:-}" ]]; then
  SWIFT_BUILD_ARGS+=(--build-system "$MAC_TERMINAL_BUILD_SYSTEM")
elif ! xcrun --find metal >/dev/null 2>&1; then
  # SwiftTerm includes shader resources. The native SwiftPM backend can copy
  # their sources on Command Line Tools-only machines without the Metal compiler.
  echo "Metal compiler unavailable; using the native SwiftPM build backend." >&2
  SWIFT_BUILD_ARGS+=(--build-system native)
fi
if [[ -n "${MAC_TERMINAL_SDK_PATH:-}" ]]; then
  if [[ ! -d "$MAC_TERMINAL_SDK_PATH" ]]; then
    echo "SDK directory does not exist: $MAC_TERMINAL_SDK_PATH" >&2
    exit 1
  fi
  SWIFT_BUILD_ARGS+=(--sdk "$MAC_TERMINAL_SDK_PATH")
fi

cd "$ROOT_DIR"
swift build "${SWIFT_BUILD_ARGS[@]}"

BINARY_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
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
# Keep dependency assets in the standard app resource directory, including
# SwiftTerm's shader assets. MacTerminal uses the CPU renderer by default.
for bundle in "$BINARY_DIR/"*.bundle; do
  [[ -d "$bundle" ]] || continue
  ditto "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
done
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --sign - "$APP_DIR" >/dev/null
test -x "$MACOS_DIR/MacTerminal"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
