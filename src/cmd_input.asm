# cmd_input.asm - INPUT command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_INPUT - Reads user input into a variable, optionally printing a string
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_INPUT:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    sw      $s2, 8($sp)

    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)         # $s0 = current token pointer
    lbu     $s1, 0($s0)         # $s1 = first token byte after INPUT

    # 1. Check if first token is string literal marker (0xC1 = 193)
    addiu   $t1, $zero, 193
    bne     $s1, $t1, DIN_PROMPT

    # Prompt with custom string literal
    addiu   $s0, $s0, 1         # Skip opening 0xC1

DIN_STR_LOOP:
    lbu     $a0, 0($s0)         # Read char from string
    addiu   $t1, $zero, 193     # 0xC1 closing marker
    beq     $a0, $t1, DIN_STR_END
    beqz    $a0, DIN_ERR         # Safety exit if null byte reached

    jal     OUTCHAR             # Print char
    addiu   $s0, $s0, 1
    j       DIN_STR_LOOP

DIN_STR_END:
    addiu   $s0, $s0, 1         # Skip closing 0xC1
    lbu     $t1, 0($s0)         # Read next token
    addiu   $t2, $zero, 59      # ';' separator (ASCII 59)
    bne     $t1, $t2, DIN_ERR
    
    addiu   $s0, $s0, 1         # Skip ';' separator
    j       DIN_VAR

DIN_PROMPT:
    addiu   $a0, $zero, 63      # '?' ASCII is 63
    jal     OUTCHAR
    addiu   $a0, $zero, 32      # ' ' (space)
    jal     OUTCHAR

DIN_VAR:
    # Read target variable token
    lbu     $s2, 0($s0)         # $s2 = variable token (0xD0-0xE9)

    # Check variable range (0xD0 = 208, 0xEA = 234)
    addiu   $t1, $zero, 208
    slt     $t2, $s2, $t1
    bnez    $t2, DIN_ERR

    addiu   $t1, $zero, 234
    slt     $t2, $s2, $t1
    beqz    $t2, DIN_ERR

    # Advance token pointer past variable
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    # Read user input into MEM_INPUT_BUF
    jal     READ_LINE

    # Parse input from MEM_INPUT_BUF
    la      $t0, MEM_INPUT_BUF
    lbu     $t1, 0($t0)         # Read first char of input buffer
    addiu   $t2, $zero, 45      # '-' ASCII is 45
    bne     $t1, $t2, DIN_PARSE

    # Negative number: skip '-' and parse
    addiu   $a0, $t0, 1
    jal     PARSE_NUMBER        # $v0 = parsed value
    
    # Negate $v0
    nor     $v0, $v0, $zero
    addiu   $v0, $v0, 1
    andi    $v0, $v0, 0xFFFF
    j       DIN_STORE

DIN_PARSE:
    la      $a0, MEM_INPUT_BUF
    jal     PARSE_NUMBER        # $v0 = parsed value

DIN_STORE:
    addu    $a0, $s2, $zero     # Variable token in $a0
    addu    $a1, $v0, $zero     # Value in $a1
    jal     VAR_SET

    lw      $s2, 8($sp)
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    j       REPL

DIN_ERR:
    lw      $s2, 8($sp)
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    j       REPL_SYNTAX_ERROR
