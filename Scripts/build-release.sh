#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT_DIR="release"
APP_NAME="ClipboardHistory"
ZIP_NAME="$APP_NAME.zip"
ARCHIVE_PATH="$OUT_DIR/$APP_NAME.xcarchive"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

cd "$OUT_DIR"
ditto -c -k --keepParent --sequesterRsrc "$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$ZIP_NAME"

SHA=$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')
SIZE=$(stat -f%z "$ZIP_NAME")

echo
echo "Built: $OUT_DIR/$ZIP_NAME"
echo "Size:  $SIZE bytes"
echo "SHA256: $SHA"
