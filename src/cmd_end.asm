# cmd_end.asm - END command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_END - Resets run flag to stop program execution
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_END:
    j       RUN_END
