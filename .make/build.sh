#!/usr/bin/env bash
# build.sh - Concatenate PBasic MIPS sources (monolith during rebuild)
# -----------------------------------------------------------------------

set -e

SRC_DIR="src"
OUT_DIR="bin"
OUT_FILE="${OUT_DIR}/pbasic.s"

mkdir -p "$OUT_DIR"

echo "# PBasic MIPS SPIM/MARS Combined Source" > "$OUT_FILE"

# Monolith during the pedagogical rebuild. Phase 9 replaces this list.
FILES=(
    "pbasic.asm"
)

for file in "${FILES[@]}"; do
    cat "${SRC_DIR}/${file}" >> "$OUT_FILE"
done

echo "Compiled MIPS source: ${OUT_FILE}"
