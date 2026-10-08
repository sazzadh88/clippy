#!/bin/sh
# Build NotchClip and (re)launch it.
set -eu
cd "$(dirname "$0")"

xcodegen -q
xcodebuild -scheme NotchClip -configuration Debug -derivedDataPath build \
  -destination "platform=macOS,arch=$(uname -m)" -quiet build

# Quit a running copy and wait for it to exit, or `open` fails with -600.
pkill -x NotchClip || true
while pgrep -x NotchClip >/dev/null; do sleep 0.1; done
open build/Build/Products/Debug/NotchClip.app
