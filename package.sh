#!/bin/sh
# Build a universal (Apple Silicon + Intel) Release of Clippy and zip it to dist/Clippy.zip.
# The app is ad-hoc signed, not notarized: on other Macs it opens after
# System Settings › Privacy & Security › Open Anyway (see README).
set -eu
cd "$(dirname "$0")"

xcodegen -q
xcodebuild -scheme Clippy -configuration Release -derivedDataPath build \
  -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO -quiet build

APP=build/Build/Products/Release/Clippy.app
mkdir -p dist
rm -f dist/Clippy.zip
ditto -c -k --keepParent "$APP" dist/Clippy.zip

echo "Built $(lipo -archs "$APP/Contents/MacOS/Clippy") → dist/Clippy.zip"
