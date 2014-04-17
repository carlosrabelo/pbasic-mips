# cmd_let.asm - LET command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_LET - Assigns an evaluated expression to a variable (A-Z)
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_LET:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)

    # 1. Read variable token
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # Current token pointer
    lbu     $s0, 0($t0)         # $s0 = variable token (0xD0-0xE9)

    # Check variable range (0xD0 = 208, 0xEA = 234)
    addiu   $t1, $zero, 208
    slt     $t2, $s0, $t1
    bnez    $t2, DL_ERR         # If token < 0xD0, error

    addiu   $t1, $zero, 234
    slt     $t2, $s0, $t1
    beqz    $t2, DL_ERR         # If token >= 0xEA, error

    # 2. Advance past variable token and check '='
    addiu   $t0, $t0, 1         # Point to '='
    lbu     $t1, 0($t0)         # Read '=' token
    addiu   $t2, $zero, 61      # '=' is ASCII 61
    bne     $t1, $t2, DL_ERR    # If not '=', error

    # 3. Advance past '=' and set MEM_TOKEN_PTR
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)

    # 4. Evaluate expression
    jal     EVAL_EXPR           # Result in $v0

    # 5. Set variable
    addu    $a0, $s0, $zero     # Variable token
    addu    $a1, $v0, $zero     # Evaluated value
    jal     VAR_SET

    # 6. Return to REPL loop
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    j       REPL

DL_ERR:
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    j       REPL_SYNTAX_ERROR
