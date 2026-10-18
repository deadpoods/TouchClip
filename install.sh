#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
zsh ./build.sh
DEST="$HOME/Applications/TouchClip.app"
if /usr/bin/pgrep -x TouchClip >/dev/null; then
  print -u2 'Quit TouchClip before installing (its Quit button or Command-Q).'
  exit 1
fi
if [[ -e "$DEST" ]]; then
  ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist")
  [[ "$ID" == local.touchclip.app ]] || { print -u2 "Refusing to replace unrelated app: $DEST"; exit 1; }
fi
mkdir -p "$HOME/Applications"
/usr/bin/ditto build/TouchClip.app "$DEST"
/usr/bin/codesign --verify --strict "$DEST"
/usr/bin/open "$DEST"
print "Installed and launched: $DEST"
