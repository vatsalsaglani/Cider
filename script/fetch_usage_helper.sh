#!/usr/bin/env bash
set -euo pipefail
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CIDER_ARCH="$(uname -m)"
case "$CIDER_ARCH" in
  arm64) CIDER_SHA=d41af4267c7074d240243df6759b23a6f005cbbbf9412bdebc6393db8c6885d4 ;;
  x86_64) CIDER_SHA=fde382eed39dd1788f11e4880a0ded3a2dba76303f70a9ebbe5bea8b8e96f2a4 ;;
  *) echo "Unsupported build architecture: $CIDER_ARCH" >&2; exit 1 ;;
esac
CIDER_CACHE="$CIDER_ROOT/.cache/codexbar/$CIDER_ARCH"
[[ -x "$CIDER_CACHE/CodexBarCLI" && -d "$CIDER_CACHE/CodexBar_CodexBarCore.bundle" ]] && exit 0
mkdir -p "$CIDER_CACHE"
CIDER_ARCHIVE="$(mktemp)"
trap 'rm -f "$CIDER_ARCHIVE"' EXIT
curl --connect-timeout 10 --max-time 120 --retry 2 -fsSL "https://github.com/steipete/CodexBar/releases/download/v0.56.6/CodexBarCLI-v0.56.6-macos-$CIDER_ARCH.tar.gz" -o "$CIDER_ARCHIVE"
[[ "$(shasum -a 256 "$CIDER_ARCHIVE" | cut -d ' ' -f 1)" == "$CIDER_SHA" ]] || exit 1
tar -xzf "$CIDER_ARCHIVE" -C "$CIDER_CACHE"
[[ -x "$CIDER_CACHE/CodexBarCLI" && -d "$CIDER_CACHE/CodexBar_CodexBarCore.bundle" ]]
