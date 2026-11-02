#!/bin/zsh
# Renders Coverlock's lock screen player to a PNG: scripts/snapshot.sh out.png [overlay|wallpaper|off]
out="${1:a}"
osascript -l JavaScript -e "ObjC.import('Foundation'); \$.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('com.krabduke.coverlock.snapshot', '$out|${2:-overlay}', \$(), true)"
