#!/bin/bash
# Builds "LG Monitor Bar.app" into build/. Pass --install to copy it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product LGMonitorBar
app="build/LG Monitor Bar.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/LGMonitorBar "$app/Contents/MacOS/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>LGMonitorBar</string>
    <key>CFBundleIdentifier</key><string>local.lg-monitor-bar</string>
    <key>CFBundleName</key><string>LG Monitor Bar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "built $app"

if [ "${1:-}" = "--install" ]; then
    pkill -x LGMonitorBar || true
    rm -rf "$HOME/Applications/LG Monitor Bar.app"
    mkdir -p "$HOME/Applications"
    cp -R "$app" "$HOME/Applications/"
    open "$HOME/Applications/LG Monitor Bar.app"
    echo "installed to ~/Applications and launched"
fi
