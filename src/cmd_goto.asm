# cmd_goto.asm - GOTO command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_GOTO - Jumps execution to a specific line number
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_GOTO:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    jal     EVAL_EXPR           # Get target line number in $v0
    
    addu    $a0, $v0, $zero     # Target line number in $a0
    jal     LINE_FIND           # Find line, returns $v0=found(1/0), $v1=node address
    beqz    $v0, DG_ERR         # If not found, syntax error

    # Enable run flag
    addiu   $t0, $zero, 1
    la      $t1, MEM_RUN_FLAG
    sw      $t0, 0($t1)

    # Update MEM_LINE_PTR to the target line node
    la      $t0, MEM_LINE_PTR
    sw      $v1, 0($t0)

    # Set MEM_TOKEN_PTR to point to the tokens of the line node ($v1 + 6)
    addiu   $v1, $v1, 6
    la      $t0, MEM_TOKEN_PTR
    sw      $v1, 0($t0)

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_DISPATCH

DG_ERR:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_SYNTAX_ERROR
