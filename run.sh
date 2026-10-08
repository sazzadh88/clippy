#!/bin/sh
# Build Clippy and (re)launch it.
set -eu
cd "$(dirname "$0")"

xcodegen -q
xcodebuild -scheme Clippy -configuration Debug -derivedDataPath build \
  -destination "platform=macOS,arch=$(uname -m)" -quiet build

# Quit a running copy and wait for it to exit, or `open` fails with -600.
pkill -x Clippy || true
while pgrep -x Clippy >/dev/null; do sleep 0.1; done
open build/Build/Products/Debug/Clippy.app
