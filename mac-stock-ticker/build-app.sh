#!/bin/bash
# Compila y empaqueta StockTicker.app (requiere las Command Line Tools de Xcode).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/StockTicker"

APP="StockTicker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/StockTicker"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>StockTicker</string>
  <key>CFBundleDisplayName</key><string>Stock Ticker</string>
  <key>CFBundleIdentifier</key><string>local.stockticker</string>
  <key>CFBundleExecutable</key><string>StockTicker</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Firma local ("ad hoc") para que macOS la deje ejecutar en esta Mac.
codesign --force --deep --sign - "$APP"

echo "Listo: $(pwd)/$APP"
echo "Para instalarla: mv $APP /Applications/ && open /Applications/$APP"
