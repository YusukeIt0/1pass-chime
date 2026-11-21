#!/bin/sh
# Builds "1PassChime.app" and per-architecture release zips into dist/.
#   scripts/build-app.sh [version]
# Signing: uses $SIGN_IDENTITY (Developer ID Application) when set, otherwise ad-hoc.
set -eu
cd "$(dirname "$0")/.."
VERSION="${1:-$(cat VERSION)}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP_NAME="1PassChime"
EXE="OnePassChime"
DIST="dist"

swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release"

rm -rf "$DIST"
mkdir -p "$DIST"
APP="$DIST/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Languages"
cp "$BIN/$EXE" "$APP/Contents/MacOS/$EXE"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
cp Resources/Languages/*.json "$APP/Contents/Resources/Languages/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

sign() {
  if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$1"
  else
    codesign --force --sign - "$1"
  fi
}
sign "$APP"
codesign --verify --strict "$APP"

# Per-architecture zips (smaller downloads); the installer picks one.
for ARCH in arm64 x86_64; do
  WORK="$DIST/$ARCH"
  mkdir -p "$WORK"
  ditto "$APP" "$WORK/$APP_NAME.app"
  lipo "$WORK/$APP_NAME.app/Contents/MacOS/$EXE" -thin "$ARCH" -output "$WORK/$EXE.thin"
  mv "$WORK/$EXE.thin" "$WORK/$APP_NAME.app/Contents/MacOS/$EXE"
  sign "$WORK/$APP_NAME.app"
  ditto -c -k --keepParent "$WORK/$APP_NAME.app" "$DIST/$APP_NAME-$VERSION-$ARCH.zip"
  rm -rf "$WORK"
done

(cd "$DIST" && shasum -a 256 "$APP_NAME"-*.zip > SHA256SUMS)
echo "Built $APP ($VERSION)"
cat "$DIST/SHA256SUMS"
