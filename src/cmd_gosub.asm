# cmd_gosub.asm - GOSUB command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_GOSUB - Pushes current line onto stack and jumps to a target
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_GOSUB:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    # Check GOSUB stack pointer depth (max depth 16)
    la      $t0, MEM_GOSUB_SP
    lw      $t1, 0($t0)         # $t1 = GOSUB stack pointer depth
    addiu   $t2, $zero, 16      # Max depth is 16
    beq     $t1, $t2, GOSUB_ERR # If full, stack overflow error

    # Push MEM_LINE_PTR to MEM_GOSUB_STK[MEM_GOSUB_SP]
    sll     $t2, $t1, 2         # Offset
    la      $t3, MEM_GOSUB_STK
    addu    $t3, $t3, $t2       # Stack slot address
    la      $t4, MEM_LINE_PTR
    lw      $t4, 0($t4)         # Current line pointer
    sw      $t4, 0($t3)         # Store on stack

    # Increment GOSUB stack pointer depth
    addiu   $t1, $t1, 1
    sw      $t1, 0($t0)

    # Evaluate target line number
    jal     EVAL_EXPR           # Target line number in $v0

    # Search for target line
    addu    $a0, $v0, $zero
    jal     LINE_FIND           # Find line, returns $v0=found(1/0), $v1=node address
    beqz    $v0, GOSUB_ERR      # If not found, error

    # Enable run flag
    addiu   $t0, $zero, 1
    la      $t1, MEM_RUN_FLAG
    sw      $t0, 0($t1)

    # Update MEM_LINE_PTR to target line node
    la      $t0, MEM_LINE_PTR
    sw      $v1, 0($t0)

    # Update MEM_TOKEN_PTR to target line's first token ($v1 + 6)
    addiu   $v1, $v1, 6
    la      $t0, MEM_TOKEN_PTR
    sw      $v1, 0($t0)

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_DISPATCH

GOSUB_ERR:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_SYNTAX_ERROR
