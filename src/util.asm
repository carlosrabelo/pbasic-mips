# util.asm - Utility routines for PBasic (MIPS)
# -----------------------------------------------------------------------
# Contains common string manipulation and parsing routines used across
# various parts of the interpreter.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# MATCH_KEYWORD - Check if input at $a0 matches keyword at $a1
# -----------------------------------------------------------------------
# Input: $a0 = input text pointer, $a1 = keyword string pointer (null-terminated)
# Output: $v0 = 1 if match, 0 if no match
#         $v1 = advanced pointer in input text (only valid if $v0 == 1)
# Clobbers: $t0, $t1, $t2, $t3
# -----------------------------------------------------------------------
MATCH_KEYWORD:
    move    $t0, $a0            # $t0 = input text iterator
    move    $t1, $a1            # $t1 = keyword iterator

MK_LOOP:
    lb      $t3, 0($t1)         # Read char from keyword
    beqz    $t3, MK_END_CHECK   # Reached end of keyword? Check boundary

    lb      $t2, 0($t0)         # Read char from input text
    bne     $t2, $t3, MK_FAIL   # If they differ, match fails

    addiu   $t0, $t0, 1         # Advance input
    addiu   $t1, $t1, 1         # Advance keyword
    j       MK_LOOP

MK_END_CHECK:
    lb      $t2, 0($t0)         # Keyword matched! Check next char in input
    beqz    $t2, MK_SUCCESS     # End of string is a valid boundary

    li      $t3, 65             # 'A'
    slt     $t3, $t2, $t3
    bne     $t3, $zero, MK_SUCCESS # Less than 'A' is valid boundary (e.g., space, punct)
    
    li      $t3, 90             # 'Z'
    slt     $t3, $t3, $t2
    bne     $t3, $zero, MK_SUCCESS # Greater than 'Z' is valid boundary
    
    # If it's another letter (A-Z), it's a partial match (e.g., PRINTER vs PRINT).
    j       MK_FAIL

MK_FAIL:
    li      $v0, 0              # Return failure
    jr      $ra

MK_SUCCESS:
    li      $v0, 1              # Return success
    move    $v1, $t0            # Return advanced pointer
    jr      $ra

# -----------------------------------------------------------------------
# PARSE_NUMBER - Parse decimal number at $a0
# -----------------------------------------------------------------------
# Input: $a0 = position in buffer
# Output: $v0 = parsed number
#         $v1 = advanced pointer (if success, else equals $a0)
# Clobbers: $t0, $t1, $t2, $t3
# -----------------------------------------------------------------------
PARSE_NUMBER:
    move    $t0, $a0            # $t0 = input text iterator
    li      $v0, 0              # Accumulator = 0
    move    $v1, $a0            # Default return pointer = original

    # Check first character to ensure it's a digit
    lb      $t1, 0($t0)
    li      $t2, 48             # '0'
    slt     $t3, $t1, $t2
    bne     $t3, $zero, PN_FAIL
    li      $t2, 57             # '9'
    slt     $t3, $t2, $t1
    bne     $t3, $zero, PN_FAIL

PN_LOOP:
    lb      $t1, 0($t0)         # Load current char
    li      $t2, 48             # '0'
    slt     $t3, $t1, $t2
    bne     $t3, $zero, PN_DONE   # If < '0', finished parsing digits
    li      $t2, 57             # '9'
    slt     $t3, $t2, $t1
    bne     $t3, $zero, PN_DONE   # If > '9', finished parsing digits

    addiu   $t1, $t1, -48       # Convert ASCII to integer value
    
    # Accumulator = Accumulator * 10 + digit
    li      $t3, 10
    mult    $v0, $t3
    mflo    $v0
    addu    $v0, $v0, $t1

    addiu   $t0, $t0, 1         # Advance pointer
    j       PN_LOOP

PN_DONE:
    move    $v1, $t0            # Return advanced pointer
    jr      $ra

PN_FAIL:
    # $v1 is already $a0
    jr      $ra
