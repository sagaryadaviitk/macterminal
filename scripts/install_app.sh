#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacTerminal.app"
SOURCE_APP="$ROOT_DIR/.build/debug/$APP_NAME"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/$APP_NAME"

safe_remove_installed_app() {
  local path="$1"

  if [[ "$path" != "$DEST_APP" ]]; then
    echo "Refusing to remove unexpected install path: $path" >&2
    exit 1
  fi

  case "$path" in
    "$HOME/Applications/"*.app)
      rm -rf -- "$path"
      ;;
    *)
      echo "Refusing to remove path outside ~/Applications app bundles: $path" >&2
      exit 1
      ;;
  esac
}

"$ROOT_DIR/scripts/package_app.sh" debug >/dev/null
mkdir -p "$DEST_DIR"
safe_remove_installed_app "$DEST_APP"
cp -R "$SOURCE_APP" "$DEST_APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

if command -v mdimport >/dev/null 2>&1; then
  mdimport "$DEST_APP" >/dev/null 2>&1 || true
fi

echo "$DEST_APP"
