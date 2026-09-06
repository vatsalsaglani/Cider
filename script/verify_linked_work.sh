#!/usr/bin/env bash
set -euo pipefail
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIDER_ROOT"
[[ "${1:-}" == "--fixtures" ]] || { echo 'Usage: verify_linked_work.sh --fixtures' >&2; exit 2; }
swift build --product Cider
CIDER_BIN="$(swift build --show-bin-path)"
mkdir -p output/qa
CIDER_OBJECTS=()
for obj in "$CIDER_BIN"/CiderDomain.build/*.o "$CIDER_BIN"/CiderData.build/*.o; do
    CIDER_OBJECTS+=("$obj")
done
swiftc -parse-as-library -I "$CIDER_BIN/Modules" -I Sources/CSQLite \
    script/verification/LinkedWorkSmoke.swift "${CIDER_OBJECTS[@]}" -lsqlite3 -o "$CIDER_BIN/linked-work-smoke"
"$CIDER_BIN/linked-work-smoke"
swift test --filter LinkedFoundationTests
swift test --filter LinkedWorkflowTests
swift test --filter LinkedJournalRecoveryTests
