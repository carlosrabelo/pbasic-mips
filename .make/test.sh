#!/usr/bin/env bash
# test.sh - Thin green check used while the interpreter is still a monolith
# -----------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUT_FILE="bin/pbasic.s"

./.make/build.sh

if [[ ! -f "$OUT_FILE" ]]; then
    echo "test: missing $OUT_FILE" >&2
    exit 1
fi

if ! grep -qE "^[[:space:]]*main:" "$OUT_FILE"; then
    echo "test: missing label main in $OUT_FILE" >&2
    exit 1
fi

echo "test: build and main label OK"
