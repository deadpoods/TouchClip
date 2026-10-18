#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/TouchClip.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -swift-version 6 -O -target "$(uname -m)-apple-macosx14.0" \
  -framework AppKit Sources/Clipboard.swift Sources/App.swift Sources/main.swift \
  -o "$APP/Contents/MacOS/TouchClip"
cp Info.plist "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - --identifier local.touchclip.app "$APP"
/usr/bin/codesign --verify --strict "$APP"
print "Built: $APP"
