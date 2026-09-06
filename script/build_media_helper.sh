#!/usr/bin/env bash
set -euo pipefail
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CIDER_SRC="$CIDER_ROOT/Vendor/MediaRemoteAdapter"
CIDER_FRAMEWORK="$CIDER_ROOT/.cache/media/MediaRemoteAdapter.framework"
mkdir -p "$CIDER_FRAMEWORK/Resources"
xcrun clang -dynamiclib -fobjc-arc -fvisibility=default -I "$CIDER_SRC/include" -I "$CIDER_SRC/src" \
  "$CIDER_SRC"/src/adapter/*.m "$CIDER_SRC"/src/private/*.m "$CIDER_SRC"/src/utility/*.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -o "$CIDER_FRAMEWORK/MediaRemoteAdapter"
cat > "$CIDER_FRAMEWORK/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>MediaRemoteAdapter</string><key>CFBundleIdentifier</key><string>app.cider.MediaRemoteAdapter</string><key>CFBundlePackageType</key><string>FMWK</string></dict></plist>
PLIST
codesign --force --sign - "$CIDER_FRAMEWORK"
