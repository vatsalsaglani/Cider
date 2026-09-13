#!/usr/bin/env bash
set -euo pipefail
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIDER_ROOT"
[[ "${1:-}" == --isolated ]] || { echo 'Usage: verify_agent_plugins.sh --isolated' >&2; exit 2; }
swift build --product Cider
CIDER_BIN="$(swift build --show-bin-path)"
CIDER_OBJECTS=()
for obj in "$CIDER_BIN"/CiderDomain.build/*.o "$CIDER_BIN"/CiderData.build/*.o; do CIDER_OBJECTS+=("$obj"); done
swiftc -parse-as-library -I "$CIDER_BIN/Modules" -I Sources/CSQLite \
    script/verification/PluginInstallSmoke.swift "${CIDER_OBJECTS[@]}" -lsqlite3 -o "$CIDER_BIN/plugin-install-smoke"
CIDER_FIXTURE="$(mktemp -d -t cider-plugin-native)"
"$CIDER_BIN/plugin-install-smoke" "$CIDER_ROOT/dist/Cider.app" "$CIDER_FIXTURE"
printf 'Isolated plugin verification files: %s\n' "$CIDER_FIXTURE"
