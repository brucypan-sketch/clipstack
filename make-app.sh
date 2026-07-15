#!/bin/zsh
# Builds ClipStack.app from the SwiftPM release binary and installs it to
# ~/Applications. Ad-hoc signed; fully local, no downloads.
set -euo pipefail
cd "${0:a:h}"

swift run ClipStackChecks
swift build -c release

APP_DIR="build/ClipStack.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp .build/release/ClipStack "$APP_DIR/Contents/MacOS/ClipStack"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.brucepan.clipstack</string>
    <key>CFBundleName</key><string>ClipStack</string>
    <key>CFBundleExecutable</key><string>ClipStack</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"

pkill -x ClipStack 2>/dev/null || true
mkdir -p ~/Applications
rm -rf ~/Applications/ClipStack.app
cp -R "$APP_DIR" ~/Applications/
open ~/Applications/ClipStack.app
echo "ClipStack installed to ~/Applications and launched."
