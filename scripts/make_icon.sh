#!/bin/bash
# Generates Resources/AppIcon.icns from a CoreGraphics-rendered PNG.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR=".build/icon"
mkdir -p "$BUILD_DIR"
PNG="$BUILD_DIR/icon_1024.png"

echo "Rendering icon…"
swift scripts/make_icon.swift "$PNG"

ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# Standard macOS icon sizes (1x and 2x).
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$px" "$px" "$PNG" --out "$ICONSET/icon_${name}.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
