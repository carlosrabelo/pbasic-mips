# cmd_return.asm - RETURN command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_RETURN - Pops a line pointer from the stack and resumes execution
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_RETURN:
    la      $t0, MEM_GOSUB_SP
    lw      $t1, 0($t0)         # $t1 = GOSUB stack pointer depth
    beqz    $t1, RETURN_ERR     # If zero, stack underflow error

    # Decrement GOSUB stack pointer depth
    addiu   $t1, $t1, -1
    sw      $t1, 0($t0)         # Save updated depth

    # Pop line pointer from MEM_GOSUB_STK[MEM_GOSUB_SP]
    sll     $t2, $t1, 2         # Offset in bytes
    la      $t3, MEM_GOSUB_STK
    addu    $t3, $t3, $t2       # Slot address
    lw      $t4, 0($t3)         # Load saved line pointer
    beqz    $t4, RUN_END        # Null return (direct-mode GOSUB) → stop run

    # Restore current line pointer
    la      $t0, MEM_LINE_PTR
    sw      $t4, 0($t0)

    # Go back to REPL loop which will advance to the next line (via RUN_NEXT)
    j       REPL

RETURN_ERR:
    j       REPL_SYNTAX_ERROR
