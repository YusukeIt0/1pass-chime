#!/bin/sh
# 1PassChime installer / updater / uninstaller.
#
#   Install or update:  curl -fsSL https://raw.githubusercontent.com/YusukeIt0/1pass-chime/main/install.sh | sh
#   Uninstall:          curl -fsSL https://raw.githubusercontent.com/YusukeIt0/1pass-chime/main/install.sh | sh -s -- --uninstall
#
# No sudo. Installs to ~/Applications. Settings are kept on update.
set -eu

REPO="YusukeIt0/1pass-chime"
APP_NAME="1PassChime"
EXE="OnePassChime"
BUNDLE_ID="io.github.yusukeit0.1passchime"
INSTALL_DIR="${ONEPASSCHIME_INSTALL_DIR:-$HOME/Applications}"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"
SUPPORT_DIR="$HOME/Library/Application Support/$APP_NAME"

case "${LANG:-}${LC_ALL:-}$(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p)" in
  *ja*) JA=1 ;;
  *) JA=0 ;;
esac
msg() { if [ "$JA" = 1 ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
fail() { msg "エラー: $1" "Error: $2" >&2; exit 1; }

quit_app() {
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  i=0
  while pgrep -f "$APP_NAME.app/Contents/MacOS/$EXE" >/dev/null 2>&1 && [ $i -lt 20 ]; do
    sleep 0.25; i=$((i + 1))
  done
  pkill -f "$APP_NAME.app/Contents/MacOS/$EXE" >/dev/null 2>&1 || true
}

uninstall() {
  msg "1PassChimeをアンインストールします…" "Uninstalling 1PassChime…"
  quit_app
  rm -rf "$APP_PATH"
  rm -rf "$SUPPORT_DIR"
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  msg "完了しました。" "Done."
}

install() {
  OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
  [ "$OS_MAJOR" -ge 14 ] || fail "macOS 14以降が必要です。" "macOS 14 or later is required."

  ARCH=$(uname -m)
  # Under Rosetta uname reports x86_64; prefer the native build.
  if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then ARCH=arm64; fi
  case "$ARCH" in arm64|x86_64) ;; *) fail "未対応のCPUです: $ARCH" "Unsupported CPU: $ARCH" ;; esac

  VERSION="${ONEPASSCHIME_VERSION:-}"
  BASE="${ONEPASSCHIME_BASE_URL:-}"
  if [ -z "$BASE" ]; then
    if [ -z "$VERSION" ]; then
      VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
      [ -n "$VERSION" ] || fail "最新リリースを取得できませんでした。" "Couldn't find the latest release."
    fi
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
  fi
  [ -n "$VERSION" ] || fail "バージョンが指定されていません。" "No version given."

  ASSET="$APP_NAME-$VERSION-$ARCH.zip"
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  msg "1PassChime $VERSION ($ARCH) をダウンロードしています…" "Downloading 1PassChime $VERSION ($ARCH)…"
  curl -fsSL "$BASE/$ASSET" -o "$TMP/$ASSET" || fail "ダウンロードに失敗しました。" "Download failed."
  curl -fsSL "$BASE/SHA256SUMS" -o "$TMP/SHA256SUMS" || fail "チェックサムを取得できませんでした。" "Couldn't get checksums."

  EXPECTED=$(awk -v f="$ASSET" '$2 == f || $2 == "*"f {print $1}' "$TMP/SHA256SUMS")
  ACTUAL=$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')
  [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || fail "チェックサムが一致しません。中止しました。" "Checksum mismatch. Aborted."

  ditto -x -k "$TMP/$ASSET" "$TMP/unpacked"
  NEW_APP="$TMP/unpacked/$APP_NAME.app"
  [ -d "$NEW_APP" ] || fail "アーカイブにアプリがありません。" "The archive does not contain the app."
  codesign --verify --strict "$NEW_APP" >/dev/null 2>&1 || fail "署名の検証に失敗しました。中止しました。" "Signature verification failed. Aborted."
  SIGNATURE=$(codesign -dvv "$NEW_APP" 2>&1)
  if printf '%s\n' "$SIGNATURE" | grep -q "^Authority=Developer ID Application: "; then
    printf '%s\n' "$SIGNATURE" | grep -qx "TeamIdentifier=27K9A27SGR" ||
      fail "署名した開発者が想定と異なります。中止しました。" "The app is signed by an unexpected developer. Aborted."
    SIGNED="developer-id"
  else
    SIGNED="adhoc"
  fi

  mkdir -p "$INSTALL_DIR"
  quit_app
  if [ -d "$APP_PATH" ]; then
    mv "$APP_PATH" "$TMP/previous.app"
    if ! mv "$NEW_APP" "$APP_PATH"; then
      mv "$TMP/previous.app" "$APP_PATH"
      fail "更新に失敗したため、元のバージョンに戻しました。" "Update failed; the previous version was restored."
    fi
    msg "更新しました（設定は保持されています）。" "Updated (your settings are kept)."
  else
    mv "$NEW_APP" "$APP_PATH"
    msg "インストールしました: $APP_PATH" "Installed: $APP_PATH"
  fi

  if [ "$SIGNED" = adhoc ]; then
    msg "注意: このビルドはApple公証済みではありません（整合性はチェックサムと署名で確認済み）。" \
        "Note: this build is not notarized by Apple (integrity verified by checksum and signature)."
  fi
  open "$APP_PATH"
  msg "メニューバーに音符のアイコンが表示されます。1Passwordが承認を求めると音が鳴ります。" \
      "Look for the note icon in the menu bar. It plays a sound when 1Password asks for approval."
}

case "${1:-}" in
  --uninstall) uninstall ;;
  ""|--install) install ;;
  *) fail "不明なオプション: $1" "Unknown option: $1" ;;
esac
