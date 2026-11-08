#!/usr/bin/env bash
# Builds Deck.app and wraps it in a drag-to-install .dmg (app + Applications symlink).
# Uses only hdiutil — no extra tooling. Pass a version for the filename, e.g. v0.1.0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-dev}"

"$ROOT/scripts/package-app.sh" release

APP="$ROOT/dist/Deck.app"
STAGE="$ROOT/dist/dmg-stage"
DMG="$ROOT/dist/Deck-$VERSION.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Deck.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Deck" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

rm -rf "$STAGE"
echo "→ built $DMG"
