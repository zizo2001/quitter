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

KS_NAME="KeyboardShortcuts_KeyboardShortcuts.bundle"
KS_BUNDLE="$BIN_DIR/$KS_NAME"
if [ -d "$KS_BUNDLE" ]; then
    cp -R "$KS_BUNDLE" "$APP/Contents/Resources/"
    # SwiftPM's generated Bundle.module looks only at <App>.app/<name> (unsealed bundle root, so
    # codesign refuses it) and then at this absolute .build path, which vanishes on `make clean`
    # (crash: "could not load resource bundle"). Repoint that fallback literal at the installed
    # copy. Swift string literals carry their length, so the replacement keeps the same byte
    # count, padded with "/./" segments.
    python3 - "$APP/Contents/MacOS/Quitter" "$(cd "$BIN_DIR" && pwd)/$KS_NAME" \
        "/Applications/Quitter.app/Contents/Resources/$KS_NAME" <<'PY'
import sys
binary, old, new = sys.argv[1], sys.argv[2].encode(), sys.argv[3]
pad = len(old) - len(new)
if pad < 0:
    sys.exit(f"build-app: install path longer than build path ({len(new)} > {len(old)})")
head, tail = new.split("/Contents/", 1)
new = (head + "/." * (pad // 2) + "/" * (pad % 2) + "/Contents/" + tail).encode()
data = open(binary, "rb").read()
if data.count(old) != 1:
    sys.exit(f"build-app: expected exactly 1 copy of the resource path, found {data.count(old)}")
open(binary, "wb").write(data.replace(old, new))
print(f"Repointed KeyboardShortcuts resource fallback -> {new.decode()}")
PY
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
