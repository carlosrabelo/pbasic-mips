# cmd_if.asm - IF command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_IF - Evaluates condition and executes THEN clause if true
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_IF:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    jal     EVAL_COND           # Evaluate condition, result in $v0
    
    # If condition is false ($v0 == 0), skip the rest of the line
    beqz    $v0, DI_FALSE

    # Condition is true! Check 'THEN' token (0x8D = 141)
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # Current token pointer
    lbu     $t1, 0($t0)         # $t1 = next token byte
    addiu   $t2, $zero, 141     # 'THEN' token
    bne     $t1, $t2, DI_ERR

    # Advance past 'THEN' token
    addiu   $t0, $t0, 1
    
    # Read the command token
    lbu     $t1, 0($t0)         # $t1 = command token

    # Check if FREE token (0xA0 = 160)
    addiu   $t2, $zero, 160
    bne     $t1, $t2, DI_NOT_FREE
    
    # Advance past FREE token
    addiu   $t0, $t0, 1
    la      $t3, MEM_TOKEN_PTR
    sw      $t0, 0($t3)
    
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       DO_FREE

DI_NOT_FREE:
    # Check if command token is valid (0x80 <= token <= 0x8C)
    addiu   $t2, $zero, 128     # 0x80
    slt     $t3, $t1, $t2
    bnez    $t3, DI_ERR         # If token < 0x80, error

    addiu   $t2, $zero, 141     # 0x8D
    slt     $t3, $t1, $t2
    beqz    $t3, DI_ERR         # If token >= 0x8D, error

    # Valid command token. Advance past it
    addiu   $t0, $t0, 1
    la      $t3, MEM_TOKEN_PTR
    sw      $t0, 0($t3)

    # Dispatch via jump table
    addiu   $t2, $t1, -128      # $t2 = token - 0x80
    sll     $t2, $t2, 2         # $t2 = offset in bytes
    la      $t3, CMD_JUMP_TABLE
    addu    $t3, $t3, $t2
    lw      $t4, 0($t3)         # Target address

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $t4

DI_FALSE:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL

DI_ERR:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL_SYNTAX_ERROR
