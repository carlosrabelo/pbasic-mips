# cmd_new.asm - NEW command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_NEW - Clears program memory and resets all variables
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_NEW:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    jal     PROG_INIT
    jal     VAR_INIT
    
    # Reset GOSUB stack pointer depth
    la      $t0, MEM_GOSUB_SP
    sw      $zero, 0($t0)

    jal     PRINT_OK

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL
