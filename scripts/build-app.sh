#!/usr/bin/env bash
# Builds build/Quitter.app from the SwiftPM release product. Pass --install to
# replace /Applications/Quitter.app and relaunch it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Quitter
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Quitter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Quitter" "$APP/Contents/MacOS/Quitter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

KS_BUNDLE="$BIN_DIR/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [ -d "$KS_BUNDLE" ]; then
    cp -R "$KS_BUNDLE" "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x Quitter || true
    sleep 0.5
    rm -rf /Applications/Quitter.app
    cp -R "$APP" /Applications/
    open /Applications/Quitter.app
    echo "Installed /Applications/Quitter.app"
fi
