#!/usr/bin/env bash
# Builds Deck and assembles a double-clickable Deck.app bundle (with a real bundle id,
# so UserNotifications work and the app runs as a menu-bar accessory).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
# Universal binary so the app runs natively on both Apple Silicon and Intel — and so it
# can be built on an Intel CI runner (arm64 macOS runners aren't available on all plans).
ARCHS="--arch arm64 --arch x86_64"

echo "→ swift build -c $CONFIG (universal)"
swift build -c "$CONFIG" $ARCHS --package-path "$ROOT"

BIN="$(swift build -c "$CONFIG" $ARCHS --package-path "$ROOT" --show-bin-path)/Deck"
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
