#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAP_NAME="aeongui/ports-localtest"
FORMULA="${TAP_NAME}/skia-aeongui"
TMP_TAP_DIR="$(mktemp -d /tmp/aeongui-ports-tap.XXXXXX)"

cleanup() {
	brew untap "$TAP_NAME" >/dev/null 2>&1 || true
	rm -rf "$TMP_TAP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_TAP_DIR/Formula"
cp "$ROOT_DIR/Formula/skia-aeongui.rb" "$TMP_TAP_DIR/Formula/skia-aeongui.rb"

git -C "$TMP_TAP_DIR" init -q
git -C "$TMP_TAP_DIR" config user.name "AeonGUI Tap Test"
git -C "$TMP_TAP_DIR" config user.email "tap-test@local"
git -C "$TMP_TAP_DIR" add Formula/skia-aeongui.rb
git -C "$TMP_TAP_DIR" commit -qm "tap test snapshot"

brew untap "$TAP_NAME" >/dev/null 2>&1 || true
brew tap "$TAP_NAME" "file://$TMP_TAP_DIR"
brew install --dry-run --build-from-source "$FORMULA"

echo "Local tap validation succeeded for $FORMULA"
