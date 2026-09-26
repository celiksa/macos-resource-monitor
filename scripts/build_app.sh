#!/bin/bash
# Builds Vitals.app: compiles a release binary and assembles a launchable .app
# bundle (Info.plist + icon + ad-hoc code signature). No Xcode required.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="Vitals.app"
CONTENTS="$APP/Contents"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Vitals"

# Generate the icon if missing.
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "▸ Generating icon…"
    bash scripts/make_icon.sh
fi

echo "▸ Assembling ${APP} …"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Vitals"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
cp "Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Ad-hoc sign so the bundle launches cleanly and keeps its identity.
echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "✓ Built $APP"
echo "  Launch with:  open $APP   (or ./$CONTENTS/MacOS/Vitals)"
