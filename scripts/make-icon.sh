#!/bin/sh
# Regenerates Resources/icon/AppIcon-1024.png and Resources/AppIcon.icns from the mark drawn
# in code (Sources/ChimeCore/Glyph.swift), plus menu bar previews in Resources/icon.
set -eu
cd "$(dirname "$0")/.."
swift build
.build/debug/OnePassChime --render-icons Resources/icon
SET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$SET"
for spec in 16x16:16 16x16@2x:32 32x32:32 32x32@2x:64 128x128:128 128x128@2x:256 256x256:256 256x256@2x:512 512x512:512 512x512@2x:1024; do
  name=${spec%%:*}; px=${spec##*:}
  sips -z "$px" "$px" Resources/icon/AppIcon-1024.png --out "$SET/icon_$name.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$(dirname "$SET")"
echo "wrote Resources/AppIcon.icns"
