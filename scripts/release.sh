#!/bin/zsh
# Builds Coverlock.app and uploads it as a GitHub release: scripts/release.sh v0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?usage: scripts/release.sh vX.Y.Z}"
./build.sh
mkdir -p dist
rm -f dist/Coverlock.zip
ditto -c -k --keepParent build/Coverlock.app dist/Coverlock.zip
gh release create "$tag" dist/Coverlock.zip --title "Coverlock $tag" --notes "Download Coverlock.zip, unzip, and move Coverlock.app to Applications. Or run the one-line installer from the README."
