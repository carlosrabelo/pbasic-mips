# cmd_rem.asm - REM command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_REM - Handles comments (REMarks) by ignoring the rest of the line
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_REM:
    j       REPL
