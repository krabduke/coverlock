#!/bin/zsh
# Shows Coverlock's lock screen player over the desktop for 10 seconds.
osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("com.krabduke.coverlock.preview", $(), $(), true)'
