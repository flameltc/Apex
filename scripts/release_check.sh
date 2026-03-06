#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="ApexPlayer"
APP_PATH=".build/release/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}.dmg"

required_files=(
  "docs/DEV_PLAN.md"
  "docs/TEST_MATRIX.md"
  "docs/BETA_RELEASE.md"
  "docs/PERF_BASELINE.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    exit 1
  fi
done

echo "[1/5] Running tests..."
swift test

echo "[2/5] Building app bundle..."
./scripts/build_app_bundle.sh

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

echo "[3/5] Building DMG..."
./scripts/build_dmg.sh

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  exit 1
fi

echo "[4/5] Verifying code signature (ad-hoc allowed)..."
codesign --verify --deep --strict "$APP_PATH" || true

echo "[5/5] Artifact summary"
ls -lh "$APP_PATH" "$DMG_PATH"
shasum -a 256 "$DMG_PATH"

echo "Release check completed."
