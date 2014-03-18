# cmd_run.asm - RUN command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_RUN - Begins execution of the stored BASIC program
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_RUN:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    la      $t0, MEM_PROG_START
    lw      $t1, 0($t0)         # Read next_ptr of first line node
    beqz    $t1, RUN_NO_PROG    # If null, empty program

    # Reset GOSUB stack pointer depth
    la      $t0, MEM_GOSUB_SP
    sw      $zero, 0($t0)

    # Set run flag to 1
    addiu   $t1, $zero, 1
    la      $t0, MEM_RUN_FLAG
    sw      $t1, 0($t0)

    # Set MEM_LINE_PTR to MEM_PROG_START
    la      $t0, MEM_PROG_START
    la      $t1, MEM_LINE_PTR
    sw      $t0, 0($t1)

    # Set MEM_TOKEN_PTR to tokens of first line node (MEM_PROG_START + 6)
    addiu   $t0, $t0, 6
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_DISPATCH

RUN_NO_PROG:
    la      $a0, MSG_NO_PROGRAM
    jal     PRINT_STR
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL
