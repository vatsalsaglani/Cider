#!/usr/bin/env bash
# Build versioned release archives and produce GitHub release notes from CHANGELOG.md.
set -euo pipefail

CIDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIDER_ROOT"

usage() {
    cat <<'USAGE'
Usage:
  script/release.sh version release/vX.Y.Z
  script/release.sh notes X.Y.Z
  script/release.sh package X.Y.Z OUTPUT_DIRECTORY
USAGE
}

version_from_branch() {
    local branch="$1"
    case "$branch" in
        release/v*) printf '%s\n' "${branch#release/v}" ;;
        release/*) printf '%s\n' "${branch#release/}" ;;
        *) echo "Release branches must be release/X.Y.Z or release/vX.Y.Z" >&2; return 2 ;;
    esac
}

validate_version() {
    local version="$1"
    [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
        echo "Version must be X.Y.Z without a prefix or leading zeroes" >&2
        return 2
    }
    printf '%s\n' "$version"
}

release_notes() {
    local version="$1"
    local heading="## [$version]"
    awk -v heading="$heading" '
        $0 == heading || index($0, heading " - ") == 1 { found = 1; next }
        found && /^## / { exit }
        found { print }
        END { if (!found) exit 3 }
    ' CHANGELOG.md
}

command="${1:-}"
case "$command" in
    version)
        [[ $# == 2 ]] || { usage >&2; exit 2; }
        validate_version "$(version_from_branch "$2")"
        ;;
    notes)
        [[ $# == 2 ]] || { usage >&2; exit 2; }
        release_notes "$(validate_version "$2")"
        ;;
    package)
        [[ $# == 3 ]] || { usage >&2; exit 2; }
        CIDER_RELEASE_VERSION="$(validate_version "$2")"
        CIDER_OUTPUT_DIRECTORY="$3"
        mkdir -p "$CIDER_OUTPUT_DIRECTORY"
        CIDER_STAGE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/cider-release.XXXXXX")"
        trap 'rm -rf "$CIDER_STAGE_DIRECTORY"' EXIT
        CIDER_BUILD_NUMBER="${CIDER_BUILD_NUMBER:-1}" \
        CIDER_VERSION="$CIDER_RELEASE_VERSION" \
        CIDER_PACKAGE_PATH="$CIDER_STAGE_DIRECTORY/Cider.app" \
            "$CIDER_ROOT/script/build_and_run.sh" --package >&2
        CIDER_ARCHIVE="$CIDER_OUTPUT_DIRECTORY/Cider-$CIDER_RELEASE_VERSION-macos.zip"
        rm -f "$CIDER_ARCHIVE" "$CIDER_ARCHIVE.sha256"
        ditto -c -k --sequesterRsrc --keepParent "$CIDER_STAGE_DIRECTORY/Cider.app" "$CIDER_ARCHIVE"
        (cd "$CIDER_OUTPUT_DIRECTORY" && shasum -a 256 "$(basename "$CIDER_ARCHIVE")") > "$CIDER_ARCHIVE.sha256"
        printf '%s\n' "$CIDER_ARCHIVE"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
