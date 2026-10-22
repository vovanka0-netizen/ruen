#!/bin/sh
# Собирает dist/RuEn.app из main.swift.
set -e
VERSION=1.0.0
cd "$(dirname "$0")"
APP=dist/RuEn.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
# Одна программа для Apple Silicon и Intel.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos26.0 main.swift -o dist/RuEn-$arch
done
lipo -create dist/RuEn-arm64 dist/RuEn-x86_64 -output "$APP/Contents/MacOS/RuEn"
rm dist/RuEn-arm64 dist/RuEn-x86_64
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
# Своим сертификатом «RuEn Local Signing», если он есть в Связке ключей: тогда macOS
# узнаёт программу после пересборки и не спрашивает доступ заново. Иначе ad-hoc.
if security find-certificate -c "RuEn Local Signing" >/dev/null 2>&1; then
  codesign --force --sign "RuEn Local Signing" "$APP"
else
  codesign --force --sign - "$APP"
fi
(cd dist && rm -f RuEn-$VERSION.zip && ditto -c -k --keepParent RuEn.app RuEn-$VERSION.zip)
# DMG: открыл, перетащил RuEn в «Программы».
rm -rf dist/dmg dist/RuEn-$VERSION.dmg
mkdir dist/dmg && cp -R "$APP" dist/dmg/ && ln -s /Applications dist/dmg/Applications
hdiutil create -quiet -volname "RuEn $VERSION" -srcfolder dist/dmg -format UDZO dist/RuEn-$VERSION.dmg
rm -rf dist/dmg
echo "Готово: $APP, dist/RuEn-$VERSION.zip, dist/RuEn-$VERSION.dmg"
