# cmd_exit.asm - EXIT command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_EXIT - Gracefully exits the interpreter
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_EXIT:
    addiu   $v0, $zero, 10      # Exit syscall code
    syscall
