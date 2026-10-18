#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build docs
xcrun swiftc -swift-version 6 -target "$(uname -m)-apple-macosx14.0" -framework AppKit \
  Sources/Clipboard.swift Sources/App.swift Tests/main.swift -o build/TouchClipTests
./build/TouchClipTests "$@"
