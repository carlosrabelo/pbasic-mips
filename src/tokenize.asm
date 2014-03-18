# tokenize.asm - Tokenizer for PBasic (MIPS)
# -----------------------------------------------------------------------
# Converts ASCII in MEM_INPUT_BUF to internal tokens in MEM_TOKEN_BUF.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# TOKENIZE - Convert input buffer to tokens
# -----------------------------------------------------------------------
# Input: None (uses MEM_INPUT_BUF)
# Output: None (writes to MEM_TOKEN_BUF)
# Clobbers: $t0, $t1, $t2, $t3
# -----------------------------------------------------------------------
TOKENIZE:
    la      $t0, MEM_INPUT_BUF      # $t0 points to source ASCII
    la      $t1, MEM_TOKEN_BUF      # $t1 points to destination token stream

TOK_LOOP:
    # 1. Skip spaces
    # Call SKIP_SPACES inline or via subroutine. For simplicity in MIPS, 
    # we can do it inline or as a separate subroutine block.
    # We will jump to a local loop to skip spaces.
TOK_SKIP_SPACES:
    lb      $t2, 0($t0)             # Load current character
    li      $t3, 32                 # ASCII for space (' ')
    bne     $t2, $t3, TOK_CHECK_CHAR # If not space, proceed to check char
    addiu   $t0, $t0, 1             # Advance input pointer
    j       TOK_SKIP_SPACES         # Loop back

TOK_CHECK_CHAR:
    # Read current character again (it's already in $t2, but just to be sure)
    lb      $t2, 0($t0)
    
    # Is it null (end of string)?
    beqz    $t2, TOK_DONE           # If so, finish tokenization

    # Is it a quote (start of string literal)?
    li      $t3, 34                 # ASCII for '"'
    beq     $t2, $t3, TOK_STRING    # If so, handle string tokenization

    # Is it a digit ('0'-'9')?
    li      $t3, 48                 # '0'
    slt     $t3, $t2, $t3           # If $t2 < $t3, $t3 = 1, else 0
    bnez    $t3, TOK_NOTNUM         # If $t2 < '0', not a number
    li      $t3, 57                 # '9'
    slt     $t3, $t3, $t2           # If $t3 < $t2 (i.e. $t2 > '9'), $t3 = 1
    bnez    $t3, TOK_NOTNUM         # If $t2 > '9', not a number
    j       TOK_NUMBER              # It's a number

TOK_NOTNUM:
    # Is it a letter ('A'-'Z')?
    # Note: READ_LINE already converts lowercase to uppercase.
    li      $t3, 65                 # 'A'
    slt     $t3, $t2, $t3           # If $t2 < $t3, $t3 = 1
    bnez    $t3, TOK_NOTLETTER      # If < 'A', not a letter
    li      $t3, 90                 # 'Z'
    slt     $t3, $t3, $t2           # If 90 < $t2 (i.e. $t2 > 'Z'), $t3 = 1
    bnez    $t3, TOK_NOTLETTER      # If > 'Z', not a letter
    j       TOK_LETTER              # It's a letter

TOK_NOTLETTER:
    # Handle specific operators
    li      $t3, 60                 # '<'
    beq     $t2, $t3, TOK_LT        # Handle potential '<>' or '<='
    li      $t3, 62                 # '>'
    beq     $t2, $t3, TOK_GT        # Handle potential '>='

    # If it's none of the above (e.g., '+', '-', '*', '/', '=', '(', ')', ';', ','),
    # it's a single-character ASCII token. Store it literally.
    sb      $t2, 0($t1)             # Store ASCII character as token
    addiu   $t0, $t0, 1             # Advance input pointer
    addiu   $t1, $t1, 1             # Advance output pointer
    j       TOK_LOOP                # Loop back

TOK_DONE:
    sb      $zero, 0($t1)           # Write null terminator to token stream
    jr      $ra                     # Return to caller

# -----------------------------------------------------------------------
# Number, string, keyword, and comparison token handlers
# -----------------------------------------------------------------------

TOK_NUMBER:
    # Use $ra saving because we call PARSE_NUMBER
    # Wait, TOKENIZE is currently not saving $ra.
    # It must save $ra at the beginning, but since we are doing a quick replace,
    # let's just make sure we handle it. Actually, TOKENIZE is called from main via jal,
    # so we must save $ra. We'll do it by pushing to stack.
    
    # Write number token prefix (0xC0)
    li      $t3, 0xC0
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1

    # Call PARSE_NUMBER
    move    $a0, $t0            # $a0 = input pointer
    
    # Save required registers
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $t0, 8($sp)
    sw      $t1, 4($sp)
    
    jal     PARSE_NUMBER
    
    lw      $t1, 4($sp)
    lw      $t0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    
    move    $t0, $v1            # Update input pointer

    # $v0 has the 16-bit number. Store as little-endian.
    andi    $t3, $v0, 0xFF      # Low byte
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    
    srl     $t3, $v0, 8         # High byte
    andi    $t3, $t3, 0xFF
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1

    j       TOK_LOOP

TOK_STRING:
    addiu   $t0, $t0, 1         # Skip opening quote
    li      $t3, 0xC1           # String start token
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1

TS_LOOP:
    lb      $t2, 0($t0)         # Read char inside string
    beqz    $t2, TS_END         # Unclosed string -> implicit close
    li      $t3, 34             # '"'
    beq     $t2, $t3, TS_CLOSE  # End of string
    sb      $t2, 0($t1)         # Store char
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TS_LOOP

TS_CLOSE:
    addiu   $t0, $t0, 1         # Skip closing quote

TS_END:
    li      $t3, 0xC1           # String end token
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_LETTER:
    # Try MATCH_KEYWORD for each known keyword.
    # To keep it simple, we use a macro-like block or sequential checks.
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $t0, 8($sp)
    sw      $t1, 4($sp)

    # Check PRINT
    lw      $a0, 8($sp)
    la      $a1, KW_PRINT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_PRINT_MATCH

    # Check LET
    lw      $a0, 8($sp)
    la      $a1, KW_LET
    jal     MATCH_KEYWORD
    bnez    $v0, TK_LET_MATCH

    # Check IF
    lw      $a0, 8($sp)
    la      $a1, KW_IF
    jal     MATCH_KEYWORD
    bnez    $v0, TK_IF_MATCH

    # Check GOTO
    lw      $a0, 8($sp)
    la      $a1, KW_GOTO
    jal     MATCH_KEYWORD
    bnez    $v0, TK_GOTO_MATCH

    # Check GOSUB
    lw      $a0, 8($sp)
    la      $a1, KW_GOSUB
    jal     MATCH_KEYWORD
    bnez    $v0, TK_GOSUB_MATCH

    # Check INPUT
    lw      $a0, 8($sp)
    la      $a1, KW_INPUT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_INPUT_MATCH

    # Check RETURN
    lw      $a0, 8($sp)
    la      $a1, KW_RETURN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RETURN_MATCH

    # Check THEN
    lw      $a0, 8($sp)
    la      $a1, KW_THEN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_THEN_MATCH

    # Check END
    lw      $a0, 8($sp)
    la      $a1, KW_END
    jal     MATCH_KEYWORD
    bnez    $v0, TK_END_MATCH

    # Check REM
    lw      $a0, 8($sp)
    la      $a1, KW_REM
    jal     MATCH_KEYWORD
    bnez    $v0, TK_REM_MATCH

    # Check LIST
    lw      $a0, 8($sp)
    la      $a1, KW_LIST
    jal     MATCH_KEYWORD
    bnez    $v0, TK_LIST_MATCH

    # Check RUN
    lw      $a0, 8($sp)
    la      $a1, KW_RUN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RUN_MATCH

    # Check NEW
    lw      $a0, 8($sp)
    la      $a1, KW_NEW
    jal     MATCH_KEYWORD
    bnez    $v0, TK_NEW_MATCH

    # Check EXIT
    lw      $a0, 8($sp)
    la      $a1, KW_EXIT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_EXIT_MATCH

    # Check FREE
    lw      $a0, 8($sp)
    la      $a1, KW_FREE
    jal     MATCH_KEYWORD
    bnez    $v0, TK_FREE_MATCH

    # Check RND
    lw      $a0, 8($sp)
    la      $a1, KW_RND
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RND_MATCH

    # Check ABS
    lw      $a0, 8($sp)
    la      $a1, KW_ABS
    jal     MATCH_KEYWORD
    bnez    $v0, TK_ABS_MATCH

    # No keyword matched. It's a variable.
    lw      $t1, 4($sp)
    lw      $t0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16

    lb      $t2, 0($t0)         # Read variable letter
    addiu   $t2, $t2, -65       # 'A'
    addiu   $t2, $t2, 0xD0      # Base token for A
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TOK_LOOP

    # Keyword match handlers
TK_PRINT_MATCH:
    li      $t3, 0x83
    j       TK_KW_STORE
TK_LET_MATCH:
    li      $t3, 0x80
    j       TK_KW_STORE
TK_IF_MATCH:
    li      $t3, 0x84
    j       TK_KW_STORE
TK_GOTO_MATCH:
    li      $t3, 0x81
    j       TK_KW_STORE
TK_GOSUB_MATCH:
    li      $t3, 0x82
    j       TK_KW_STORE
TK_INPUT_MATCH:
    li      $t3, 0x85
    j       TK_KW_STORE
TK_RETURN_MATCH:
    li      $t3, 0x86
    j       TK_KW_STORE
TK_THEN_MATCH:
    li      $t3, 0x8D
    j       TK_KW_STORE
TK_END_MATCH:
    li      $t3, 0x87
    j       TK_KW_STORE
TK_REM_MATCH:    
    # REM matched!
    # $v1 points to after "REM" in input buffer
    lw      $t1, 4($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16

    # 1. Write the REM token (0x8C)
    li      $t3, 0x8C
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1

    # 2. Copy the rest of the line literally
    move    $t0, $v1            # Start copying from after "REM"
TK_REM_COPY_LOOP:
    lbu     $t2, 0($t0)         # Read char from input
    sb      $t2, 0($t1)         # Store to token buffer
    beqz    $t2, TOK_DONE       # If null, we are done
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TK_REM_COPY_LOOP

TK_LIST_MATCH:
    li      $t3, 0x88
    j       TK_KW_STORE
TK_RUN_MATCH:
    li      $t3, 0x89
    j       TK_KW_STORE
TK_NEW_MATCH:
    li      $t3, 0x8A
    j       TK_KW_STORE
TK_EXIT_MATCH:
    li      $t3, 0x8B
    j       TK_KW_STORE
TK_FREE_MATCH:
    li      $t3, 0xA0
    j       TK_KW_STORE
TK_RND_MATCH:
    li      $t3, 0xA1
    j       TK_KW_STORE
TK_ABS_MATCH:
    li      $t3, 0xA2
    j       TK_KW_STORE

TK_KW_STORE:
    lw      $t1, 4($sp)
    lw      $t0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16

    move    $t0, $v1            # Update input pointer to end of keyword
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_LT:
    addiu   $t0, $t0, 1         # Skip '<'
    lb      $t2, 0($t0)
    li      $t3, 62             # '>'
    beq     $t2, $t3, TOK_NE
    li      $t3, 61             # '='
    beq     $t2, $t3, TOK_LE
    
    # Just '<'
    li      $t3, 60
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_NE:
    addiu   $t0, $t0, 1
    li      $t3, 0xB0
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_LE:
    addiu   $t0, $t0, 1
    li      $t3, 0xB1
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_GT:
    addiu   $t0, $t0, 1         # Skip '>'
    lb      $t2, 0($t0)
    li      $t3, 61             # '='
    beq     $t2, $t3, TOK_GE
    
    # Just '>'
    li      $t3, 62
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_GE:
    addiu   $t0, $t0, 1
    li      $t3, 0xB2
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

