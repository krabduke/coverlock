#!/bin/zsh
# One-line setup for a new Mac:
#   curl -fsSL https://raw.githubusercontent.com/krabduke/coverlock/main/install.sh | zsh
#
# Installs Coverlock (lock-screen music player), Faders (per-app volume) and Boring Notch
# (dynamic island for the notch), then opens them. Pass --coverlock-only to skip the other two.
set -euo pipefail

REPO="krabduke/coverlock"
BORING_NOTCH_VERSION="v2.8-rc.2"   # first release with macOS 27 fixes
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> Installing Coverlock"
curl -fsSL "https://github.com/$REPO/releases/latest/download/Coverlock.zip" -o "$tmp/Coverlock.zip"
ditto -x -k "$tmp/Coverlock.zip" "$tmp"
pkill -x Coverlock 2>/dev/null || true
rm -rf /Applications/Coverlock.app
ditto "$tmp/Coverlock.app" /Applications/Coverlock.app
xattr -dr com.apple.quarantine /Applications/Coverlock.app 2>/dev/null || true
open /Applications/Coverlock.app

if [[ "${1:-}" != "--coverlock-only" ]]; then
  echo "==> Installing Faders"
  curl -fsSL "https://github.com/krabduke/faders/releases/latest/download/Faders.zip" -o "$tmp/Faders.zip"
  ditto -x -k "$tmp/Faders.zip" "$tmp"
  pkill -x Faders 2>/dev/null || true
  rm -rf /Applications/Faders.app
  ditto "$tmp/Faders.app" /Applications/Faders.app
  xattr -dr com.apple.quarantine /Applications/Faders.app 2>/dev/null || true
  open /Applications/Faders.app

  echo "==> Installing Boring Notch $BORING_NOTCH_VERSION"
  curl -fsSL "https://github.com/TheBoredTeam/boring.notch/releases/download/$BORING_NOTCH_VERSION/boringNotch.dmg" -o "$tmp/boringNotch.dmg"
  mnt=$(hdiutil attach -nobrowse -readonly "$tmp/boringNotch.dmg" | tail -1 | awk -F'\t' '{print $NF}')
  pkill -f "Boring Notch.app/Contents/MacOS" 2>/dev/null || true
  rm -rf "/Applications/Boring Notch.app"
  ditto "$mnt/Boring Notch.app" "/Applications/Boring Notch.app"
  hdiutil detach -quiet "$mnt"
  xattr -dr com.apple.quarantine "/Applications/Boring Notch.app" 2>/dev/null || true
  open "/Applications/Boring Notch.app"
fi

cat <<'MSG'

Done. Two things to do by hand:
  1. Turn on "Open at login" in the ♪ menu (Coverlock) and in the sliders panel
     (Faders), and "Launch at login" in Boring Notch's settings (⭐ menu), or they
     won't come back after a restart.
  2. Allow the permission prompts: Coverlock asks to control Spotify/Music,
     Faders asks for "Screen & System Audio Recording" the first time you change
     an app's volume, Boring Notch asks for "Device Control and Data Access".
MSG
