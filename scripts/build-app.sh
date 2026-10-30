#!/bin/zsh
# Builds Vibecabulary.app and installs it to /Applications (removing the old Glossary.app).
# Usage: scripts/build-app.sh [--no-install]
set -euo pipefail
cd "$(dirname "$0")/.."

NAME=Vibecabulary
APP=build/$NAME.app
VERSION=1.0

swift build -c release --product Glossary
BIN="$(swift build -c release --show-bin-path)/Glossary"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$NAME"
cp Resources/sample-glossary.json "$APP/Contents/Resources/"

if [[ ! -f build/AppIcon.icns ]]; then
  swift tools/make_icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.vibecabulary.app</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" != "--no-install" ]]; then
  pkill -x "$NAME" 2>/dev/null || true
  pkill -x Glossary 2>/dev/null || true
  rm -rf "/Applications/$NAME.app" /Applications/Glossary.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/$NAME.app"
fi
