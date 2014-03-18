# cmd_print.asm - PRINT command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_PRINT - Evaluates and prints expressions, strings, or formats output
# Input:  None (uses MEM_TOKEN_PTR)
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_PRINT:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)

DP_LOOP:
    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)         # $s0 = current token pointer
    lbu     $s1, 0($s0)         # $s1 = current token byte

    # Check for EOL (0x00)
    beqz    $s1, DP_CRLF

    # Check for string literal marker (0xC1 = 193)
    addiu   $t1, $zero, 193
    beq     $s1, $t1, DP_STRING

    # Check for semicolon ';' (ASCII 59)
    addiu   $t1, $zero, 59
    beq     $s1, $t1, DP_SEMI

    # Check for comma ',' (ASCII 44)
    addiu   $t1, $zero, 44
    beq     $s1, $t1, DP_COMMA

    # Otherwise, it's an expression
    jal     EVAL_EXPR           # Result in $v0

    # Print as a 32-bit integer so FREE (~52 KB) and negatives both work
    addu    $a0, $v0, $zero
    jal     PRINT_NUMBER
    j       DP_LOOP

DP_STRING:
    # Skip the opening 0xC1 marker
    addiu   $s0, $s0, 1

DP_STR_LOOP:
    lbu     $a0, 0($s0)         # Read character
    addiu   $t1, $zero, 193     # 0xC1 closing marker
    beq     $a0, $t1, DP_STR_END
    beqz    $a0, DP_STR_NUL     # Unclosed string: stop at token-stream NUL

    jal     OUTCHAR             # Print char
    addiu   $s0, $s0, 1         # Move to next char
    j       DP_STR_LOOP

DP_STR_NUL:
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    j       DP_LOOP

DP_STR_END:
    # Skip the closing 0xC1 marker
    addiu   $s0, $s0, 1

    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)         # Save advanced pointer
    j       DP_LOOP

DP_SEMI:
    # Skip the semicolon
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    # If the next token is 0x00, we suppress the CRLF and exit
    lbu     $t1, 0($s0)
    beqz    $t1, DP_EXIT_NO_CRLF
    j       DP_LOOP

DP_COMMA:
    # Skip the comma
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    # Print 8 spaces
    addiu   $s1, $zero, 8
DP_TAB_LOOP:
    addiu   $a0, $zero, 32      # Space character
    jal     OUTCHAR
    addiu   $s1, $s1, -1
    bnez    $s1, DP_TAB_LOOP
    j       DP_LOOP

DP_CRLF:
    jal     PRINT_CRLF

DP_EXIT_NO_CRLF:
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    j       REPL
