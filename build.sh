#!/bin/sh
# Собирает dist/RuEn.app из main.swift.
set -e
VERSION=0.2
cd "$(dirname "$0")"
APP=dist/RuEn.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/RuEn"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.vova.ruen</string>
  <key>CFBundleName</key><string>RuEn</string>
  <key>CFBundleExecutable</key><string>RuEn</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
(cd dist && rm -f RuEn-$VERSION.zip && ditto -c -k --keepParent RuEn.app RuEn-$VERSION.zip)
echo "Готово: $APP и dist/RuEn-$VERSION.zip"
