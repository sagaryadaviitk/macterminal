#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$("$ROOT_DIR/scripts/package_app.sh" "${1:-debug}" | tail -n 1)"
open "$APP_DIR"
