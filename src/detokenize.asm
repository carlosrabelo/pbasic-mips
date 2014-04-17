# detokenize.asm - Token-to-text conversion for PBasic (MIPS)
# -----------------------------------------------------------------------
# Converts internal token streams back to human-readable text.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# PRINT_TOKENS - Print token stream at $a0 as text.
# -----------------------------------------------------------------------
# Input: $a0 = pointer to token buffer
# Output: None
# Clobbers: $t0, $t1, $a0, $v0
# -----------------------------------------------------------------------
PRINT_TOKENS:
    # Save $ra and any preserved registers we might use
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)

    move    $s0, $a0            # $s0 = token pointer iterator

PTO_LOOP:
    lb      $t0, 0($s0)         # Read current token
    andi    $t0, $t0, 0xFF      # Unsign it
    beqz    $t0, PTO_DONE       # End of stream

    addiu   $s0, $s0, 1         # Advance pointer

    # Is it >= 0x80?
    li      $t1, 128
    bge     $t0, $t1, PTO_NOT_ASCII

    # It's an ASCII char
    move    $a0, $t0
    jal     OUTCHAR
    j       PTO_LOOP

PTO_NOT_ASCII:
    # Is it number token 0xC0?
    li      $t1, 0xC0
    beq     $t0, $t1, PTO_NUM

    # Is it string token 0xC1?
    li      $t1, 0xC1
    beq     $t0, $t1, PTO_STR

    # Is it a keyword (0x80 <= token < 0xD0 or >= 0xA0)?
    li      $t1, 0xD0
    blt     $t0, $t1, PTO_KW

    # Check for invalid range >= 0xEA
    li      $t1, 0xEA
    bge     $t0, $t1, PTO_LOOP

    # It's a variable token 0xD0 - 0xE9
    addiu   $a0, $t0, -0xD0
    addiu   $a0, $a0, 65        # 'A'
    jal     OUTCHAR
    j       PTO_LOOP

PTO_KW:
    move    $a0, $t0            # Keyword token in $a0
    jal     PRINT_KEYWORD
    j       PTO_LOOP

PTO_NUM:
    # Read two bytes LE
    lb      $t1, 0($s0)
    andi    $t1, $t1, 0xFF
    addiu   $s0, $s0, 1

    lb      $t2, 0($s0)
    andi    $t2, $t2, 0xFF
    addiu   $s0, $s0, 1

    sll     $t2, $t2, 8
    or      $a0, $t1, $t2       # $a0 = (high << 8) | low
    
    # Sign extend 16 to 32? No, memory addresses / line numbers are unsigned or small positive
    jal     PRINT_NUMBER
    j       PTO_LOOP

PTO_STR:
    li      $a0, 34             # '"'
    jal     OUTCHAR

PTO_SL:
    lb      $t1, 0($s0)
    andi    $t1, $t1, 0xFF
    addiu   $s0, $s0, 1
    
    li      $t2, 0xC1
    beq     $t1, $t2, PTO_SE    # End of string
    beqz    $t1, PTO_DONE       # Abort safely

    move    $a0, $t1
    jal     OUTCHAR
    j       PTO_SL

PTO_SE:
    li      $a0, 34             # '"'
    jal     OUTCHAR
    j       PTO_LOOP

PTO_DONE:
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra

# -----------------------------------------------------------------------
# PRINT_KEYWORD - Print text for keyword token in $a0
# -----------------------------------------------------------------------
PRINT_KEYWORD:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)

    move    $s0, $a0            # Save token
    
    # 0x80 <= token <= 0x8D
    li      $t1, 0x80
    blt     $s0, $t1, PKW_CHECK_A
    li      $t1, 0x8D
    bgt     $s0, $t1, PKW_CHECK_A

    # O(1) Lookup
    addiu   $t2, $s0, -0x80
    sll     $t2, $t2, 2         # token * 4 (word size)
    la      $t1, PKW_TABLE
    addu    $t1, $t1, $t2
    lw      $a0, 0($t1)         # Load string pointer
    jal     PRINT_STR
    j       PKW_DONE

PKW_CHECK_A:
    li      $t1, 0xA0
    beq     $s0, $t1, PKW_E
    li      $t1, 0xA1
    beq     $s0, $t1, PKW_F
    li      $t1, 0xA2
    beq     $s0, $t1, PKW_G

    li      $t1, 0xB0
    beq     $s0, $t1, PKW_H
    li      $t1, 0xB1
    beq     $s0, $t1, PKW_I
    li      $t1, 0xB2
    beq     $s0, $t1, PKW_J
    
    j       PKW_DONE

PKW_E:
    la      $a0, PKWS_FREE
    j       PKW_PS
PKW_F:
    la      $a0, PKWS_RND
    j       PKW_PS
PKW_G:
    la      $a0, PKWS_ABS
    j       PKW_PS
PKW_H:
    la      $a0, PKWS_NE
    j       PKW_PS
PKW_I:
    la      $a0, PKWS_LE
    j       PKW_PS
PKW_J:
    la      $a0, PKWS_GE
    j       PKW_PS

PKW_PS:
    jal     PRINT_STR

PKW_DONE:
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra
