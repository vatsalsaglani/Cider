#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIDER_ROOT"
case "$MODE" in run|--debug|--logs|--telemetry|--verify) ;; *) echo 'Use run, --debug, --logs, --telemetry, or --verify' >&2; exit 2;; esac
swift build --product Cider
swift build --product cider-events
CIDER_BUILD="$(swift build --show-bin-path)"
CIDER_APP="$CIDER_ROOT/dist/Cider.app"
mkdir -p "$CIDER_APP/Contents/MacOS"
pkill -x Cinder >/dev/null 2>&1 || true
pkill -x Cider >/dev/null 2>&1 || true
mkdir -p "$CIDER_APP/Contents/Resources"
cp -R "$CIDER_BUILD/Cider_CiderPlatform.bundle" "$CIDER_APP/Contents/Resources/"
cp "$CIDER_BUILD/Cider" "$CIDER_APP/Contents/MacOS/Cider"
cat > "$CIDER_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Cider</string>
<key>CFBundleIdentifier</key><string>app.cinder.desktop</string>
<key>CFBundleName</key><string>Cider</string>
<key>CFBundleDisplayName</key><string>Cider</string>
<key>CFBundleIconFile</key><string>Cider.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSAppleEventsUsageDescription</key><string>Cider shows the current song from Music and Spotify in your notch.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
"$CIDER_ROOT/script/fetch_usage_helper.sh"
mkdir -p "$CIDER_APP/Contents/Helpers"
cp "$CIDER_BUILD/cider-events" "$CIDER_APP/Contents/Helpers/"
CIDER_HELPER="$CIDER_ROOT/.cache/codexbar/$(uname -m)"
cp -R "$CIDER_HELPER/CodexBarCLI" "$CIDER_HELPER/CodexBar_CodexBarCore.bundle" "$CIDER_APP/Contents/Helpers/"
cp "$CIDER_ROOT/docs/implementation/CodexBar-LICENSE" "$CIDER_APP/Contents/Helpers/CodexBar-LICENSE"
cp "$CIDER_ROOT/Sources/CiderPlatform/Resources/branding/Cider.icns" "$CIDER_APP/Contents/Resources/Cider.icns"
"$CIDER_ROOT/script/build_media_helper.sh"
cp -R "$CIDER_ROOT/.cache/media/MediaRemoteAdapter.framework" "$CIDER_APP/Contents/Helpers/"
cp "$CIDER_ROOT/Vendor/MediaRemoteAdapter/bin/mediaremote-adapter.pl" "$CIDER_APP/Contents/Helpers/"
cp "$CIDER_ROOT/Vendor/MediaRemoteAdapter/LICENSE" "$CIDER_APP/Contents/Helpers/MediaRemoteAdapter-LICENSE"
codesign --force --deep --sign - "$CIDER_APP"
if [[ "$MODE" == --debug ]]; then exec lldb -- "$CIDER_APP/Contents/MacOS/Cider"; fi
/usr/bin/open -n "$CIDER_APP"
case "$MODE" in
 --verify) sleep 1; pgrep -x Cider >/dev/null ;;
 --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "Cider"' ;;
 --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "app.cinder.desktop"' ;;
esac
