#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

REPO_DIR="${KML_REPO_DIR:-$PROJECT_ROOT/output/repo}"
PORT="${KML_REPO_PORT:-8000}"

if [[ ! -f "$REPO_DIR/repodata/repomd.xml" ]]; then
    echo "ERROR: repository metadata is missing: $REPO_DIR/repodata/repomd.xml" >&2
    echo "Run scripts/build-branding-rpm.sh first." >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to serve the repository." >&2
    exit 1
fi

echo "Serving $REPO_DIR on 0.0.0.0:$PORT"
echo "QEMU user-mode guest URL: http://10.0.2.2:$PORT/"
echo "Press Ctrl-C to stop."

exec python3 -m http.server --bind 0.0.0.0 --directory "$REPO_DIR" "$PORT"
