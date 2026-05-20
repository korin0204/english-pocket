#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/release/English Pocket.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release --product EnglishPocketMac

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/EnglishPocketMac" "$MACOS_DIR/EnglishPocketMac"
cp "$ROOT_DIR/AppResources/EnglishPocketInfo.plist" "$CONTENTS_DIR/Info.plist"

echo "Built: $APP_DIR"
