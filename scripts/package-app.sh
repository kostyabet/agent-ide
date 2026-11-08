#!/usr/bin/env bash
# Builds Deck and assembles a double-clickable Deck.app bundle (with a real bundle id,
# so UserNotifications work and the app runs as a menu-bar accessory).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG" --package-path "$ROOT"

BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/Deck"
APP="$ROOT/dist/Deck.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Deck"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# app icon — regenerate if missing, then drop into the bundle
if [ ! -f "$ROOT/Resources/AppIcon.icns" ]; then
  echo "→ generating AppIcon.icns"
  swift "$ROOT/scripts/make-icon.swift"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc sign so macOS keeps a stable identity across rebuilds (needed for the
# Automation/Notifications permission grants to stick)
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "→ built $APP"
echo "  open it with:  open \"$APP\""
