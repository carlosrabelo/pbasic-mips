# commands.asm - Core execution engine and commands for PBasic (MIPS)
# -----------------------------------------------------------------------
# Maps tokens to command execution handlers and handles direct execution.
# -----------------------------------------------------------------------

.data

.align 2
CMD_JUMP_TABLE:
    .word DO_LET              # 0x80: LET
    .word DO_GOTO             # 0x81: GOTO
    .word DO_GOSUB            # 0x82: GOSUB
    .word DO_PRINT            # 0x83: PRINT
    .word DO_IF               # 0x84: IF
    .word DO_INPUT            # 0x85: INPUT
    .word DO_RETURN           # 0x86: RETURN
    .word DO_END              # 0x87: END
    .word DO_LIST             # 0x88: LIST
    .word DO_RUN              # 0x89: RUN
    .word DO_NEW              # 0x8A: NEW
    .word DO_EXIT             # 0x8B: EXIT
    .word DO_REM              # 0x8C: REM

.text

# -----------------------------------------------------------------------
# REPL_DISPATCH - Main instruction dispatch logic.
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: $t0, $t1, $t2, $t3, $t4
# -----------------------------------------------------------------------
REPL_DISPATCH:
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # $t0 = current token pointer
    lbu     $t1, 0($t0)         # $t1 = current token byte

    # 1) Check if empty line (0x00)
    beqz    $t1, REPL_LOOP_DONE

    # 2) Check if line number (0xC0 = 192)
    addiu   $t2, $zero, 192
    beq     $t1, $t2, REPL_STORE_LINE

    # 3) Check if FREE token (0xA0 = 160)
    addiu   $t2, $zero, 160
    bne     $t1, $t2, RD_NOT_FREE
    # Advance token pointer past FREE
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    j       DO_FREE

RD_NOT_FREE:
    # 4) Check if token is < 0x80 (128)
    addiu   $t2, $zero, 128
    slt     $t3, $t1, $t2       # $t3 = 1 if token < 128
    bnez    $t3, REPL_SYNTAX_ERROR

    # 5) Check if token is >= 0x8D (141)
    addiu   $t2, $zero, 141
    slt     $t3, $t1, $t2       # $t3 = 1 if token < 141 (so if 0, then >= 141)
    beqz    $t3, REPL_SYNTAX_ERROR

    # 6) Valid command (0x80 <= token <= 0x8C)
    # Calculate jump table offset: (token - 0x80) * 4
    addiu   $t2, $t1, -128      # $t2 = token - 0x80
    sll     $t2, $t2, 2         # $t2 = offset in bytes
    
    # Advance token pointer past the command token
    addiu   $t0, $t0, 1
    la      $t3, MEM_TOKEN_PTR
    sw      $t0, 0($t3)

    # Load target address from CMD_JUMP_TABLE
    la      $t3, CMD_JUMP_TABLE
    addu    $t3, $t3, $t2
    lw      $t4, 0($t3)         # $t4 = target address

    # Jump to target address
    jr      $t4
