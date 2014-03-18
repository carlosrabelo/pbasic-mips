#!/usr/bin/env bash
# build.sh - Helper script to combine PBasic MIPS sources
# -----------------------------------------------------------------------

set -e

# Directories
SRC_DIR="src"
OUT_DIR="bin"
OUT_FILE="${OUT_DIR}/pbasic.s"

# Ensure output directory exists
mkdir -p "$OUT_DIR"

# Start the combined file
echo "# PBasic MIPS SPIM/MARS Combined Source" > "$OUT_FILE"

# Concatenation order. SPIM/MARS are two-pass assemblers, so main.asm
# may reference labels defined in later files.
FILES=(
    "main.asm"
    "defs.inc"
    "strings.asm"
    "util.asm"
    "variables.asm"
    "math.asm"
    "expr.asm"
    "repl.asm"
    "commands.asm"
    "cmd_let.asm"
    "cmd_goto.asm"
    "cmd_gosub.asm"
    "cmd_print.asm"
    "cmd_if.asm"
    "cmd_input.asm"
    "cmd_return.asm"
    "cmd_end.asm"
    "cmd_list.asm"
    "cmd_run.asm"
    "cmd_new.asm"
    "cmd_exit.asm"
    "cmd_free.asm"
    "cmd_rem.asm"
    "io.asm"
    "tokenize.asm"
    "detokenize.asm"
    "memmgr.asm"
    "lines.asm"
)

# Concatenate all files into the output
for file in "${FILES[@]}"; do
    cat "${SRC_DIR}/${file}" >> "$OUT_FILE"
done

echo "Compiled MIPS source: ${OUT_FILE}"
