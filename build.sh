#!/bin/zsh
# Builds build/Coverlock.app. Pass --install to copy it to /Applications and relaunch it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
app=build/Coverlock.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Coverlock "$app/Contents/MacOS/Coverlock"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Coverlock || true
  rm -rf /Applications/Coverlock.app
  cp -R "$app" /Applications/Coverlock.app
  open /Applications/Coverlock.app
  echo "Installed and launched /Applications/Coverlock.app"
fi
