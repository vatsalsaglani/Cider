#!/usr/bin/env bash
set -euo pipefail
CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIDER_ROOT"
mkdir -p output/qa
swiftc -parse-as-library script/verification/EditorProbe.swift -o output/qa/editor-probe
output/qa/editor-probe
