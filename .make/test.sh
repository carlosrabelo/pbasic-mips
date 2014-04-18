#!/usr/bin/env bash
# test.sh - Label check plus optional SPIM run of demos/99_test.bas
# -----------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SRC_DIR="src"
OUT_FILE="bin/pbasic.s"
BUILD_SCRIPT=".make/build.sh"
DEMO="demos/99_test.bas"

./.make/build.sh

if [[ ! -f "$OUT_FILE" ]]; then
    echo "test: missing $OUT_FILE" >&2
    exit 1
fi

# Every source file must be listed in build.sh and exist on disk.
mapfile -t SRC_FILES < <(find "$SRC_DIR" -maxdepth 1 -type f \( -name '*.asm' -o -name '*.inc' \) | sed 's|.*/||' | sort)
for file in "${SRC_FILES[@]}"; do
    if ! grep -qE "^[[:space:]]*\"${file}\"" "$BUILD_SCRIPT"; then
        echo "test: $file is not listed in $BUILD_SCRIPT" >&2
        exit 1
    fi
done

LABELS=(
    main
    TOKENIZE
    MATCH_KEYWORD
    REPL_DISPATCH
    EVAL_EXPR
    EVAL_FACTOR
    EVAL_TERM
    EVAL_COND
    PROG_INIT
    LINE_FIND
    LINE_STORE
    MEM_OPEN_HOLE
    MEM_CLOSE_HOLE
    MEM_PROG_LIMIT
    VAR_INIT
    VAR_GET
    VAR_SET
    MUL16
    DIV16
    MOD16
    DO_PRINT
    DO_LET
    DO_NEW
    DO_REM
    DO_FREE
    DO_RUN
    DO_END
    DO_EXIT
    DO_GOTO
    DO_GOSUB
    DO_RETURN
    DO_IF
    DO_INPUT
    PRINT_TOKENS
    INCHAR
    OUTCHAR
    READ_LINE
)

for label in "${LABELS[@]}"; do
    if ! grep -qE "^[[:space:]]*${label}:" "$OUT_FILE"; then
        echo "test: missing label ${label} in $OUT_FILE" >&2
        exit 1
    fi
done

echo "test: labels and source list OK"

if ! command -v spim >/dev/null 2>&1; then
    echo "test: SPIM not installed; skipping runtime demo"
    exit 0
fi

if [[ ! -f "$DEMO" ]]; then
    echo "test: missing $DEMO" >&2
    exit 1
fi

# Do not pass -mapped_io: syscall 8 must read the redirected demo file.
output="$(spim -file "$OUT_FILE" < "$DEMO" 2>&1)" || {
    echo "test: SPIM exited with error" >&2
    echo "$output" >&2
    exit 1
}

if ! grep -q -- "--- TEST COMPLETE ---" <<<"$output"; then
    echo "test: missing --- TEST COMPLETE --- in SPIM output" >&2
    echo "$output" >&2
    exit 1
fi
if ! grep -q -- "IN SUBROUTINE!" <<<"$output"; then
    echo "test: missing IN SUBROUTINE! in SPIM output" >&2
    echo "$output" >&2
    exit 1
fi
if ! grep -q -- "ABS OF -15 IS:" <<<"$output"; then
    echo "test: missing ABS OF -15 IS: in SPIM output" >&2
    echo "$output" >&2
    exit 1
fi
if ! grep -qE -- "NEG FIFTEEN IS:[[:space:]]*-15" <<<"$output"; then
    echo "test: missing NEG FIFTEEN IS: -15 in SPIM output" >&2
    echo "$output" >&2
    exit 1
fi
if ! grep -qE -- "ABS OF -15 IS:[[:space:]]*15" <<<"$output"; then
    echo "test: unexpected ABS output (expected 15)" >&2
    echo "$output" >&2
    exit 1
fi

echo "test: SPIM demo OK"
