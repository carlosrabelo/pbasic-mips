# cmd_free.asm - FREE command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_FREE - Calculates and prints the remaining free memory bytes
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_FREE:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    la      $t0, MEM_PROG_LIMIT
    lw      $t0, 0($t0)         # First byte after the 52 KB buffer
    la      $t1, MEM_PROG_END
    lw      $t1, 0($t1)         # Current program end
    subu    $a0, $t0, $t1       # $a0 = free bytes
    
    jal     PRINT_NUMBER
    jal     PRINT_CRLF

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL
