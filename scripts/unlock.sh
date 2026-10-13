#!/bin/bash
# remove a stale live-build lock after a crashed/killed build (refuses if lb is still running)
if pgrep -x -f 'lb|live-build' >/dev/null || pgrep -f '/usr/lib/live/build' >/dev/null; then echo "live-build still running; not unlocking"; exit 1; fi
rm -fv /var/tmp/novac-build/.lock
mount | grep novac-build && { echo "stale mounts remain"; exit 1; } || echo "no stale mounts"
