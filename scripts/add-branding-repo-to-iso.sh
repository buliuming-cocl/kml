#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

INPUT_ISO="${1:-$PROJECT_ROOT/output/Fedora-Everything-netinst-x86_64-44-1.7.iso}"
OUTPUT_ISO="${2:-$PROJECT_ROOT/output/Fedora-Everything-netinst-x86_64-44-1.7-kml.iso}"
REPO_DIR="${KML_REPO_DIR:-$PROJECT_ROOT/output/repo}"

if [[ "$(basename "$REPO_DIR")" != "repo" ]]; then
    echo "ERROR: repository directory must be named 'repo' so it maps to /repo on the ISO." >&2
    exit 1
fi

for path in "$INPUT_ISO" "$REPO_DIR/repodata/repomd.xml"; do
    if [[ ! -f "$path" ]]; then
        echo "ERROR: missing required file: $path" >&2
        exit 1
    fi
done

if ! command -v mkksiso >/dev/null 2>&1; then
    echo "ERROR: mkksiso is required." >&2
    exit 1
fi

rm -f "$OUTPUT_ISO"

mkksiso \
    --skip-mkefiboot \
    --add "$REPO_DIR" \
    "$INPUT_ISO" \
    "$OUTPUT_ISO"

echo
echo "Created ISO with embedded branding repository:"
echo "  $OUTPUT_ISO"
