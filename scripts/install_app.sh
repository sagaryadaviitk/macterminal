#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacTerminal.app"
PROCESS_NAME="MacTerminal"
CONFIGURATION="${1:-release}"
SOURCE_APP="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
DEST_DIR="${MAC_TERMINAL_INSTALL_DIR:-$HOME/Applications}"
# Update the existing system-wide copy rather than creating a duplicate app.
if [[ -z "${MAC_TERMINAL_INSTALL_DIR:-}" && -d "/Applications/$APP_NAME" ]]; then
  DEST_DIR="/Applications"
fi
DEST_APP="$DEST_DIR/$APP_NAME"

ensure_app_stopped() {
  if pgrep -x "$PROCESS_NAME" >/dev/null; then
    echo "Quit $PROCESS_NAME before reinstalling it; open sessions are not stopped automatically." >&2
    exit 1
  fi
}
ensure_app_stopped
case "$DEST_DIR" in
  /*) ;;
  *) echo "Install directory must be an absolute path" >&2; exit 1 ;;
esac

"$ROOT_DIR/scripts/package_app.sh" "$CONFIGURATION" >/dev/null
mkdir -p "$DEST_DIR"
STAGING_DIR="$(mktemp -d "$DEST_DIR/.app-install.XXXXXX")"
PREVIOUS_APP=""
cleanup() {
  local status=$?
  if [[ "$status" -ne 0 && -n "$PREVIOUS_APP" && ! -e "$DEST_APP" && -d "$PREVIOUS_APP" ]]; then
    mv "$PREVIOUS_APP" "$DEST_APP"
  fi
  rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT

# Copy the app only. Shell dotfiles, plugins, profiles and preferences stay in place.
ditto "$SOURCE_APP" "$STAGING_DIR/$APP_NAME"
test -x "$STAGING_DIR/$APP_NAME/Contents/MacOS/$PROCESS_NAME"
codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME"

ensure_app_stopped
if [[ -e "$DEST_APP" ]]; then
  BACKUP_DIR="$HOME/Library/Application Support/$PROCESS_NAME/Install Backups/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$BACKUP_DIR"
  PREVIOUS_APP="$BACKUP_DIR/$APP_NAME"
  mv "$DEST_APP" "$PREVIOUS_APP"
  echo "Previous app preserved at: $PREVIOUS_APP" >&2
fi
mv "$STAGING_DIR/$APP_NAME" "$DEST_APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi
if command -v mdimport >/dev/null 2>&1; then
  mdimport "$DEST_APP" >/dev/null 2>&1 || true
fi

echo "$DEST_APP"
