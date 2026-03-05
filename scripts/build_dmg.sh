#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ApexPlayer"
BUILD_DIR=".build/release"
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
DMG_DIR="dist"
DMG_PATH="$DMG_DIR/${APP_NAME}.dmg"

"$(dirname "$0")/build_app_bundle.sh"

mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"

hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
echo "Created $DMG_PATH"
