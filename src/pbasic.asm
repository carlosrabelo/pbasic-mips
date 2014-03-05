# pbasic.asm - PBasic interpreter (monolith during pedagogical rebuild)
# -----------------------------------------------------------------------

.data
    # --- Data buffers ---
    MEM_INPUT_BUF:  .space 128     # Raw text input buffer (128 bytes)
    MEM_TOKEN_BUF:  .space 160     # Tokenized line buffer (160 bytes)

    # --- Variables ---
    MEM_VARS:       .space 104     # Variables A-Z (26 x 4 bytes)

    # --- Stack and Pointers ---
    MEM_GOSUB_STK:  .space 64      # GOSUB return address stack (16 levels x 4 bytes)
    MEM_GOSUB_SP:   .word 0        # Current GOSUB stack pointer depth
    MEM_RAND_SEED:  .word 12345    # Random number generator seed
    MEM_TOKEN_PTR:  .word 0        # Pointer to the current token being evaluated
    MEM_LINE_PTR:   .word 0        # Pointer to the start of the currently executing BASIC line
    MEM_RUN_FLAG:   .word 0        # Execution state flag (1 = running, 0 = interactive)
    MEM_PROG_END:   .word 0        # Pointer to the end of the user BASIC program
    MEM_PROG_LIMIT: .word 0        # First byte after the program buffer (set in PROG_INIT)
    MEM_SCRATCH:    .word 0        # Temporary 32-bit storage for routines
    MEM_SCRATCH_LEN:.word 0        # Temporary 32-bit storage for lengths

    # 52 KB program area. SPIM 8.0 .space immediates are 16-bit signed, so
    # the reservation is split into chunks that fit in 15 bits.
    MEM_PROG_START: .space 8192
                    .space 8192
                    .space 8192
                    .space 8192
                    .space 8192
                    .space 8192
                    .space 4096

    # --- Static Strings ---
    STR_PROMPT:     .asciiz "> "
    STR_CRLF:       .asciiz "\n"
    MSG_BANNER:     .asciiz "PBasic\n"
    MSG_OK:         .asciiz "OK\n"
    MSG_ERROR:      .asciiz "?SYNTAX ERROR\n"
    MSG_NO_PROGRAM: .asciiz "?NO PROGRAM\n"
    MSG_OUT_OF_MEMORY: .asciiz "?OUT OF MEMORY\n"
    KW_LET:         .asciiz "LET"
    KW_GOTO:        .asciiz "GOTO"
    KW_GOSUB:       .asciiz "GOSUB"
    KW_PRINT:       .asciiz "PRINT"
    KW_IF:          .asciiz "IF"
    KW_INPUT:       .asciiz "INPUT"
    KW_RETURN:      .asciiz "RETURN"
    KW_END:         .asciiz "END"
    KW_LIST:        .asciiz "LIST"
    KW_RUN:         .asciiz "RUN"
    KW_NEW:         .asciiz "NEW"
    KW_EXIT:        .asciiz "EXIT"
    KW_REM:         .asciiz "REM"
    KW_THEN:        .asciiz "THEN"
    KW_FREE:        .asciiz "FREE"
    KW_RND:         .asciiz "RND"
    KW_ABS:         .asciiz "ABS"
    PKWS_LET:       .asciiz "LET "
    PKWS_GOTO:      .asciiz "GOTO "
    PKWS_GOSUB:     .asciiz "GOSUB "
    PKWS_PRINT:     .asciiz "PRINT "
    PKWS_IF:        .asciiz "IF "
    PKWS_INPUT:     .asciiz "INPUT "
    PKWS_RETURN:    .asciiz "RETURN"
    PKWS_END:       .asciiz "END"
    PKWS_LIST:      .asciiz "LIST"
    PKWS_RUN:       .asciiz "RUN"
    PKWS_NEW:       .asciiz "NEW"
    PKWS_EXIT:      .asciiz "EXIT"
    PKWS_REM:       .asciiz "REM"
    PKWS_THEN:      .asciiz "THEN "
    PKWS_FREE:      .asciiz "FREE"
    PKWS_RND:       .asciiz "RND"
    PKWS_ABS:       .asciiz "ABS"
    PKWS_NE:        .asciiz "<>"
    PKWS_LE:        .asciiz "<="
    PKWS_GE:        .asciiz ">="
    .align 2
PKW_TABLE:
    .word PKWS_LET
    .word PKWS_GOTO
    .word PKWS_GOSUB
    .word PKWS_PRINT
    .word PKWS_IF
    .word PKWS_INPUT
    .word PKWS_RETURN
    .word PKWS_END
    .word PKWS_LIST
    .word PKWS_RUN
    .word PKWS_NEW
    .word PKWS_EXIT
    .word PKWS_REM
    .word PKWS_THEN

.text
.globl main

main:
    # SPIM and MARS initialize $sp on startup (MARS: 0x7FFFEFFC).
    # No manual stack initialization is required.
    jal     PROG_INIT
    jal     VAR_INIT
    jal     REPL
    j       HALT_LOOP

# -----------------------------------------------------------------------
# PROG_INIT - Sentinel + 52 KB limit word
# -----------------------------------------------------------------------
PROG_INIT:
    la      $t0, MEM_PROG_START
    addiu   $t1, $zero, 16384
    addiu   $t1, $t1, 16384
    addiu   $t1, $t1, 16384
    addiu   $t1, $t1, 4096
    addu    $t1, $t0, $t1
    la      $t2, MEM_PROG_LIMIT
    sw      $t1, 0($t2)
    sw      $zero, 0($t0)
    addiu   $t0, $t0, 4
    la      $t2, MEM_PROG_END
    sw      $t0, 0($t2)
    jr      $ra

HALT_LOOP:
    addiu   $v0, $zero, 10
    syscall

# -----------------------------------------------------------------------
# REPL - Read-Eval-Print Loop (prompt + read; tokenize/dispatch come later)
# -----------------------------------------------------------------------
REPL:
    la      $a0, STR_PROMPT
    jal     PRINT_STR
    jal     READ_LINE
    jal     TOKENIZE
    la      $t0, MEM_TOKEN_BUF
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    j       REPL_DISPATCH

# -----------------------------------------------------------------------
# TOKENIZE - Convert MEM_INPUT_BUF to tokens in MEM_TOKEN_BUF
# -----------------------------------------------------------------------
TOKENIZE:
    la      $t0, MEM_INPUT_BUF
    la      $t1, MEM_TOKEN_BUF

TOK_LOOP:
TOK_SKIP_SPACES:
    lb      $t2, 0($t0)
    li      $t3, 32
    bne     $t2, $t3, TOK_CHECK_CHAR
    addiu   $t0, $t0, 1
    j       TOK_SKIP_SPACES

TOK_CHECK_CHAR:
    lb      $t2, 0($t0)
    beqz    $t2, TOK_DONE
    li      $t3, 34
    beq     $t2, $t3, TOK_STRING
    li      $t3, 48
    slt     $t3, $t2, $t3
    bnez    $t3, TOK_NOTNUM
    li      $t3, 57
    slt     $t3, $t3, $t2
    bnez    $t3, TOK_NOTNUM
    j       TOK_NUMBER

TOK_NOTNUM:
    li      $t3, 65
    slt     $t3, $t2, $t3
    bnez    $t3, TOK_NOTLETTER
    li      $t3, 90
    slt     $t3, $t3, $t2
    bnez    $t3, TOK_NOTLETTER
    j       TOK_LETTER

TOK_NOTLETTER:
    li      $t3, 60
    beq     $t2, $t3, TOK_LT
    li      $t3, 62
    beq     $t2, $t3, TOK_GT
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_LT:
    addiu   $t0, $t0, 1
    lb      $t2, 0($t0)
    li      $t3, 62
    beq     $t2, $t3, TOK_NE
    li      $t3, 61
    beq     $t2, $t3, TOK_LE
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
    addiu   $t0, $t0, 1
    lb      $t2, 0($t0)
    li      $t3, 61
    beq     $t2, $t3, TOK_GE
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

TOK_DONE:
    sb      $zero, 0($t1)
    jr      $ra

# Stubs until later tokenizer checkboxes
TOK_NUMBER:
    li      $t3, 0xC0
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    move    $a0, $t0
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $t0, 8($sp)
    sw      $t1, 4($sp)
    jal     PARSE_NUMBER
    lw      $t1, 4($sp)
    lw      $t0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    move    $t0, $v1
    andi    $t3, $v0, 0xFF
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    srl     $t3, $v0, 8
    andi    $t3, $t3, 0xFF
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

# -----------------------------------------------------------------------
# PARSE_NUMBER - Decimal ASCII at $a0 -> $v0, advanced ptr in $v1
# -----------------------------------------------------------------------
PARSE_NUMBER:
    move    $t0, $a0
    li      $v0, 0
    move    $v1, $a0
    lb      $t1, 0($t0)
    li      $t2, 48
    slt     $t3, $t1, $t2
    bne     $t3, $zero, PN_FAIL
    li      $t2, 57
    slt     $t3, $t2, $t1
    bne     $t3, $zero, PN_FAIL
PN_LOOP:
    lb      $t1, 0($t0)
    li      $t2, 48
    slt     $t3, $t1, $t2
    bne     $t3, $zero, PN_DONE
    li      $t2, 57
    slt     $t3, $t2, $t1
    bne     $t3, $zero, PN_DONE
    addiu   $t1, $t1, -48
    li      $t3, 10
    mult    $v0, $t3
    mflo    $v0
    addu    $v0, $v0, $t1
    addiu   $t0, $t0, 1
    j       PN_LOOP
PN_DONE:
    move    $v1, $t0
    jr      $ra
PN_FAIL:
    jr      $ra

TOK_STRING:
    addiu   $t0, $t0, 1
    li      $t3, 0xC1
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
TS_LOOP:
    lb      $t2, 0($t0)
    beqz    $t2, TS_END
    li      $t3, 34
    beq     $t2, $t3, TS_CLOSE
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TS_LOOP
TS_CLOSE:
    addiu   $t0, $t0, 1
TS_END:
    li      $t3, 0xC1
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_LETTER:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $t0, 8($sp)
    sw      $t1, 4($sp)

    lw      $a0, 8($sp)
    la      $a1, KW_PRINT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_PRINT_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_LET
    jal     MATCH_KEYWORD
    bnez    $v0, TK_LET_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_IF
    jal     MATCH_KEYWORD
    bnez    $v0, TK_IF_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_GOTO
    jal     MATCH_KEYWORD
    bnez    $v0, TK_GOTO_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_GOSUB
    jal     MATCH_KEYWORD
    bnez    $v0, TK_GOSUB_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_INPUT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_INPUT_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_RETURN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RETURN_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_THEN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_THEN_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_END
    jal     MATCH_KEYWORD
    bnez    $v0, TK_END_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_REM
    jal     MATCH_KEYWORD
    bnez    $v0, TK_REM_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_LIST
    jal     MATCH_KEYWORD
    bnez    $v0, TK_LIST_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_RUN
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RUN_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_NEW
    jal     MATCH_KEYWORD
    bnez    $v0, TK_NEW_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_EXIT
    jal     MATCH_KEYWORD
    bnez    $v0, TK_EXIT_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_FREE
    jal     MATCH_KEYWORD
    bnez    $v0, TK_FREE_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_RND
    jal     MATCH_KEYWORD
    bnez    $v0, TK_RND_MATCH
    lw      $a0, 8($sp)
    la      $a1, KW_ABS
    jal     MATCH_KEYWORD
    bnez    $v0, TK_ABS_MATCH

    lw      $t1, 4($sp)
    lw      $t0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    lb      $t2, 0($t0)
    addiu   $t2, $t2, -65
    addiu   $t2, $t2, 0xD0
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TOK_LOOP

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
    lw      $t1, 4($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    li      $t3, 0x8C
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    move    $t0, $v1
TK_REM_COPY_LOOP:
    lbu     $t2, 0($t0)
    sb      $t2, 0($t1)
    beqz    $t2, TOK_DONE
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
    move    $t0, $v1
    sb      $t3, 0($t1)
    addiu   $t1, $t1, 1
    j       TOK_LOOP

# -----------------------------------------------------------------------
# MATCH_KEYWORD - Match keyword at $a1 against input at $a0
# -----------------------------------------------------------------------
MATCH_KEYWORD:
    move    $t0, $a0
    move    $t1, $a1
MK_LOOP:
    lb      $t3, 0($t1)
    beqz    $t3, MK_END_CHECK
    lb      $t2, 0($t0)
    bne     $t2, $t3, MK_FAIL
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       MK_LOOP
MK_END_CHECK:
    lb      $t2, 0($t0)
    beqz    $t2, MK_SUCCESS
    li      $t3, 65
    slt     $t3, $t2, $t3
    bne     $t3, $zero, MK_SUCCESS
    li      $t3, 90
    slt     $t3, $t3, $t2
    bne     $t3, $zero, MK_SUCCESS
    j       MK_FAIL
MK_FAIL:
    li      $v0, 0
    jr      $ra
MK_SUCCESS:
    li      $v0, 1
    move    $v1, $t0
    jr      $ra

# -----------------------------------------------------------------------
# INCHAR - Read a single character (syscall 12)
# -----------------------------------------------------------------------
INCHAR:
    li      $v0, 12
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# OUTCHAR - Print a single character (syscall 11)
# -----------------------------------------------------------------------
OUTCHAR:
    li      $v0, 11
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# PRINT_STR / PRINT_NUMBER / PRINT_CRLF
# -----------------------------------------------------------------------
PRINT_STR:
    li      $v0, 4
    syscall
    jr      $ra

PRINT_NUMBER:
    li      $v0, 1
    syscall
    jr      $ra

PRINT_CRLF:
    la      $a0, STR_CRLF
    li      $v0, 4
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# READ_LINE - Read a line, strip CR/LF, uppercase a-z
# -----------------------------------------------------------------------
READ_LINE:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    la      $a0, MEM_INPUT_BUF
    li      $a1, 127
    li      $v0, 8
    syscall

    la      $t0, MEM_INPUT_BUF
    lbu     $t1, 0($t0)
    beqz    $t1, READ_LINE_EOF

READ_LINE_LOOP:
    lbu     $t1, 0($t0)
    beqz    $t1, READ_LINE_DONE
    li      $t2, 10
    beq     $t1, $t2, RL_TRUNCATE
    li      $t2, 13
    beq     $t1, $t2, RL_TRUNCATE
    li      $v0, 97
    slt     $a1, $t1, $v0
    bne     $a1, $zero, READ_LINE_NEXT
    li      $v0, 122
    slt     $a1, $v0, $t1
    bne     $a1, $zero, READ_LINE_NEXT
    addiu   $t1, $t1, -32
    sb      $t1, 0($t0)

READ_LINE_NEXT:
    addiu   $t0, $t0, 1
    j       READ_LINE_LOOP

RL_TRUNCATE:
    sb      $zero, 0($t0)

READ_LINE_DONE:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $ra

READ_LINE_EOF:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    li      $v0, 10
    syscall
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

# LINE_FIND
# -----------------------------------------------------------------------
# Description: Finds line by number.
# Input: $a0 = target line number (16-bit)
# Output: $v0 = 1 if found exactly, 0 if not
#         $v1 = pointer to node or insertion point
# -----------------------------------------------------------------------
LINE_FIND:
    la      $t0, MEM_PROG_START
    
LF_LOOP:
    lw      $t1, 0($t0)             # Read next_ptr
    beqz    $t1, LF_MISS            # End of list -> insertion point is here
    
    # Read line number (16-bit little-endian)
    lbu     $t2, 4($t0)             # low byte
    lbu     $t3, 5($t0)             # high byte
    sll     $t3, $t3, 8
    or      $t2, $t2, $t3           # $t2 = node line number
    
    beq     $t2, $a0, LF_HIT
    bgt     $t2, $a0, LF_MISS       # Passed it -> insertion point is here
    
    move    $t0, $t1
    j       LF_LOOP
    
LF_HIT:
    li      $v0, 1
    move    $v1, $t0
    jr      $ra
    
LF_MISS:
    li      $v0, 0
    move    $v1, $t0
    jr      $ra

# -----------------------------------------------------------------------
# memmgr.asm - Program Memory Manager for PBasic (MIPS)
# -----------------------------------------------------------------------
# Handles dynamic memory shifts for inserting and deleting lines,
# as well as updating the 32-bit linked list pointers.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# MEM_OPEN_HOLE
# -----------------------------------------------------------------------
# Description: Shifts memory right to open a gap for new insertion.
# Input: $a0 = Insertion pointer threshold
#        $a1 = Size in bytes to open
# Output: $v0 = 1 on success, 0 if the hole would pass MEM_PROG_LIMIT
# Clobbers: $t0, $t1, $t2, $t3
# -----------------------------------------------------------------------
MEM_OPEN_HOLE:
    lw      $t0, MEM_PROG_END       # $t0 = end of program (source end)
    addu    $t2, $t0, $a1           # $t2 = destination pointer (end + size)
    lw      $t3, MEM_PROG_LIMIT
    sltu    $t1, $t3, $t2           # 1 if new end > limit
    bnez    $t1, MOH_FAIL

    move    $t1, $t0                # $t1 = source pointer
    
    # Check if we need to copy at all (if insertion is at the end)
    beq     $a0, $t0, MOH_DONE

MOH_LOOP:
    # Copy word by word backwards when possible (4 bytes at a time)
    subu    $t1, $t1, 4
    subu    $t2, $t2, 4
    lw      $t3, 0($t1)
    sw      $t3, 0($t2)
    bgt     $t1, $a0, MOH_LOOP      # If we haven't reached insertion point, continue
    
    # Handle remaining bytes (0-3 bytes)
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 4
    bge     $t1, $a0, MOH_DONE      # Already done
    
MOH_LOOP_BYTE:
    subu    $t1, $t1, 1
    subu    $t2, $t2, 1
    lb      $t3, 0($t1)
    sb      $t3, 0($t2)
    bne     $t1, $a0, MOH_LOOP_BYTE
    
MOH_DONE:
    # Update MEM_PROG_END
    lw      $t0, MEM_PROG_END
    addu    $t0, $t0, $a1
    sw      $t0, MEM_PROG_END
    addiu   $v0, $zero, 1
    jr      $ra

MOH_FAIL:
    addu    $v0, $zero, $zero
    jr      $ra

# -----------------------------------------------------------------------
# MEM_CLOSE_HOLE
# -----------------------------------------------------------------------
# Description: Shifts memory left to overwrite and delete a gap.
# Input: $a0 = Start pointer of deletion
#        $a1 = Size in bytes to delete
# Output: None
# Clobbers: $t0, $t1, $t2, $t3
# -----------------------------------------------------------------------
MEM_CLOSE_HOLE:
    lw      $t0, MEM_PROG_END       # $t0 = end of program
    addu    $t1, $a0, $a1           # $t1 = source pointer (start + size)
    move    $t2, $a0                # $t2 = destination pointer (start)
    
    # Check if there is anything to move
    bge     $t1, $t0, MCH_DONE

MCH_LOOP:
    # Copy word by word forwards when possible (4 bytes at a time)
    lw      $t3, 0($t1)
    sw      $t3, 0($t2)
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 4
    blt     $t1, $t0, MCH_LOOP      # Loop until source pointer reaches original end
    
    # Handle remaining bytes (0-3 bytes)
    addiu   $t1, $t1, -4
    addiu   $t2, $t2, -4
    bge     $t1, $t0, MCH_DONE      # Already done
    
MCH_LOOP_BYTE:
    lb      $t3, 0($t1)
    sb      $t3, 0($t2)
    addiu   $t1, $t1, 1
    addiu   $t2, $t2, 1
    blt     $t1, $t0, MCH_LOOP_BYTE
    
MCH_DONE:
    # Update MEM_PROG_END
    lw      $t0, MEM_PROG_END
    subu    $t0, $t0, $a1
    sw      $t0, MEM_PROG_END
    jr      $ra

# -----------------------------------------------------------------------
# FIX_NEXT_ADD
# -----------------------------------------------------------------------
# Description: Adds an offset to all next_ptrs that point beyond a threshold.
# Input: $a0 = Threshold pointer
#        $a1 = Size to add
# Output: None
# Clobbers: $t0, $t1, $t2
# -----------------------------------------------------------------------
FIX_NEXT_ADD:
    la      $t0, MEM_PROG_START     # Start of program
FNA_LOOP:
    lw      $t1, 0($t0)             # Read next_ptr (32-bit)
    beqz    $t1, FNA_DONE           # If null, end of list
    ble     $t1, $a0, FNA_NEXT      # If next_ptr <= threshold, skip modification
    
    # Add size to next_ptr
    addu    $t2, $t1, $a1
    sw      $t2, 0($t0)             # Write back next_ptr
    
FNA_NEXT:
    move    $t0, $t1                # Move to next node
    j       FNA_LOOP
FNA_DONE:
    jr      $ra

# -----------------------------------------------------------------------
# FIX_NEXT_SUB
# -----------------------------------------------------------------------
# Description: Subtracts an offset from all next_ptrs pointing beyond threshold.
# Input: $a0 = Threshold pointer
#        $a1 = Size to subtract
# Output: None
# Clobbers: $t0, $t1, $t2
# -----------------------------------------------------------------------
FIX_NEXT_SUB:
    la      $t0, MEM_PROG_START
FNS_LOOP:
    lw      $t1, 0($t0)
    beqz    $t1, FNS_DONE
    ble     $t1, $a0, FNS_NEXT      # If next_ptr <= threshold, skip modification
    
    # Sub size from next_ptr
    subu    $t2, $t1, $a1
    sw      $t2, 0($t0)
    
FNS_NEXT:
    move    $t0, $t1
    j       FNS_LOOP
FNS_DONE:
    jr      $ra

# TOKEN_LEN
# -----------------------------------------------------------------------
# Description: Calculates the length of a token stream.
# Input: $a0 = pointer to tokens
# Output: $v0 = length in bytes (including the 0x00 terminator)
# -----------------------------------------------------------------------
TOKEN_LEN:
    move    $t0, $a0
    li      $v0, 0
TLN_LOOP:
    lbu     $t1, 0($t0)
    addiu   $t0, $t0, 1
    addiu   $v0, $v0, 1
    beqz    $t1, TLN_DONE
    li      $t2, 0xC0
    beq     $t1, $t2, TLN_NUM
    li      $t2, 0xC1
    beq     $t1, $t2, TLN_STR
    j       TLN_LOOP
TLN_NUM:
    addiu   $t0, $t0, 2             # skip 16-bit number
    addiu   $v0, $v0, 2
    j       TLN_LOOP
TLN_STR:
    lbu     $t1, 0($t0)
    addiu   $t0, $t0, 1
    addiu   $v0, $v0, 1
    li      $t2, 0xC1
    bne     $t1, $t2, TLN_STR
    j       TLN_LOOP
TLN_DONE:
    jr      $ra

# -----------------------------------------------------------------------
# NODE_LEN
# -----------------------------------------------------------------------
# Description: Calculates total node length.
# Input: $a0 = pointer to node (starts at next_ptr)
# Output: $v0 = total length in bytes
# -----------------------------------------------------------------------
NODE_LEN:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    
    addiu   $a0, $a0, 6             # Skip header: 4 bytes (ptr) + 2 bytes (num)
    jal     TOKEN_LEN
    
    addiu   $v0, $v0, 6             # Total length = tokens + header
    
    # Align to 4 bytes for MIPS architecture
    addiu   $v0, $v0, 3
    li      $t9, 0xFFFFFFFC
    and     $v0, $v0, $t9
    
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra

# -----------------------------------------------------------------------
# LINE_FIND
# -----------------------------------------------------------------------
# Description: Finds line by number.
# Input: $a0 = target line number (16-bit)
# Output: $v0 = 1 if found exactly, 0 if not
#         $v1 = pointer to node or insertion point
# -----------------------------------------------------------------------
LINE_FIND:
    la      $t0, MEM_PROG_START
    
LF_LOOP:
    lw      $t1, 0($t0)             # Read next_ptr
    beqz    $t1, LF_MISS            # End of list -> insertion point is here
    
    # Read line number (16-bit little-endian)
    lbu     $t2, 4($t0)             # low byte
    lbu     $t3, 5($t0)             # high byte
    sll     $t3, $t3, 8
    or      $t2, $t2, $t3           # $t2 = node line number
    
    beq     $t2, $a0, LF_HIT
    bgt     $t2, $a0, LF_MISS       # Passed it -> insertion point is here
    
    move    $t0, $t1
    j       LF_LOOP
    
LF_HIT:
    li      $v0, 1
    move    $v1, $t0
    jr      $ra
    
LF_MISS:
    li      $v0, 0
    move    $v1, $t0
    jr      $ra

# -----------------------------------------------------------------------
# LINE_STORE
# -----------------------------------------------------------------------
# Description: Store/replace/delete a BASIC line from MEM_TOKEN_BUF.
# -----------------------------------------------------------------------
LINE_STORE:
    addiu   $sp, $sp, -40
    sw      $ra, 36($sp)
    sw      $s0, 32($sp)            # Target line number
    sw      $s1, 28($sp)            # Node body pointer
    sw      $s2, 24($sp)            # Target insertion pointer
    sw      $s3, 20($sp)            # New node length
    sw      $s4, 16($sp)            # Token-stream length (including NUL)
    
    la      $t0, MEM_TOKEN_BUF
    addiu   $t0, $t0, 1             # Skip 0xC0 marker
    
    # Read target line number
    lbu     $t1, 0($t0)
    lbu     $t2, 1($t0)
    sll     $t2, $t2, 8
    or      $s0, $t1, $t2
    addiu   $t0, $t0, 2
    
    move    $s1, $t0                # $s1 points to tokens body
    
    # Is it a delete operation? (body is just 0x00)
    lbu     $t1, 0($t0)
    beqz    $t1, LS_DELETE
    
    # --- INSERT / REPLACE ---
    move    $a0, $s0
    jal     LINE_FIND
    move    $s2, $v1
    
    beqz    $v0, LS_INSERT          # If not found exactly, insert
    
    # Replace it (delete old, then insert new)
    move    $a0, $s2
    jal     NODE_LEN
    move    $s3, $v0                # length to delete
    
    move    $a0, $s2
    move    $a1, $s3
    jal     FIX_NEXT_SUB            # Fix all subsequent next_ptrs before closing hole
    
    move    $a0, $s2
    move    $a1, $s3
    jal     MEM_CLOSE_HOLE
    
    # Re-find insertion point since memory shifted
    move    $a0, $s0
    jal     LINE_FIND
    move    $s2, $v1
    
LS_INSERT:
    # Calculate new node length
    move    $a0, $s1
    jal     TOKEN_LEN
    move    $s4, $v0                # bytes to copy (includes 0x00; not the number's inner 0x00)
    addiu   $s3, $v0, 6             # new length = tokens + 6
    
    # Align to 4 bytes for MIPS
    addiu   $s3, $s3, 3
    li      $t9, 0xFFFFFFFC
    and     $s3, $s3, $t9
    
    # Refuse before mutating pointers if the new node would overflow.
    la      $t0, MEM_PROG_END
    lw      $t0, 0($t0)
    addu    $t0, $t0, $s3
    lw      $t1, MEM_PROG_LIMIT
    sltu    $t2, $t1, $t0           # 1 if new end > limit
    bnez    $t2, LS_OMEM

    # Fix subsequent next_ptrs BEFORE opening hole. Threshold is the insertion point.
    move    $a0, $s2
    move    $a1, $s3
    jal     FIX_NEXT_ADD

    # Open hole
    move    $a0, $s2
    move    $a1, $s3
    jal     MEM_OPEN_HOLE
    beqz    $v0, LS_OMEM
    
    # Write new node header
    # 1) next_ptr
    addu    $t0, $s2, $s3
    sw      $t0, 0($s2)             # Write next_ptr (32-bit absolute)
    
    # 2) Line number (16-bit little-endian)
    andi    $t0, $s0, 0xFF
    sb      $t0, 4($s2)
    srl     $t0, $s0, 8
    andi    $t0, $t0, 0xFF
    sb      $t0, 5($s2)
    
    # 3) Copy tokens by counted length (0x00 appears inside 0xC0 numbers)
    addiu   $t0, $s2, 6             # dest
    move    $t1, $s1                # src
    move    $t3, $s4                # remaining bytes
LS_COPY_TOK:
    beqz    $t3, LS_DONE
    lbu     $t2, 0($t1)
    sb      $t2, 0($t0)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    addiu   $t3, $t3, -1
    j       LS_COPY_TOK
    
LS_DELETE:
    move    $a0, $s0
    jal     LINE_FIND
    beqz    $v0, LS_DONE            # If not found, ignore deletion
    
    move    $s2, $v1
    move    $a0, $s2
    jal     NODE_LEN
    move    $s3, $v0                # length to delete
    
    move    $a0, $s2
    move    $a1, $s3
    jal     FIX_NEXT_SUB
    
    move    $a0, $s2
    move    $a1, $s3
    jal     MEM_CLOSE_HOLE
    
LS_OMEM:
    la      $a0, MSG_OUT_OF_MEMORY
    jal     PRINT_STR

LS_DONE:
    lw      $s4, 16($sp)
    lw      $s3, 20($sp)
    lw      $s2, 24($sp)
    lw      $s1, 28($sp)
    lw      $s0, 32($sp)
    lw      $ra, 36($sp)
    addiu   $sp, $sp, 40
    jr      $ra

# -----------------------------------------------------------------------

# CMD_LIST
# -----------------------------------------------------------------------
# Description: Prints all tokenized BASIC lines to the screen.
# -----------------------------------------------------------------------
CMD_LIST:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)
    
    la      $s0, MEM_PROG_START
    
LSL_LOOP:
    lw      $t0, 0($s0)
    beqz    $t0, LSL_DONE           # Stop if next_ptr is null
    
    # Read line number
    lbu     $t1, 4($s0)
    lbu     $t2, 5($s0)
    sll     $t2, $t2, 8
    or      $a0, $t1, $t2
    jal     PRINT_NUMBER
    
    # Print space separator
    li      $a0, 32
    jal     OUTCHAR
    
    # Print tokens (starts at offset 6)
    addiu   $a0, $s0, 6
    jal     PRINT_TOKENS
    jal     PRINT_CRLF
    
    # Move to next node
    lw      $s0, 0($s0)
    j       LSL_LOOP
    
LSL_DONE:
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra
# variables.asm - Variable storage and management for PBasic (MIPS)
# -----------------------------------------------------------------------
# Handles 26 32-bit variables A-Z. Stored at MEM_VARS.
# Tokens for variables: 0xD0=A, 0xD1=B, ..., 0xE9=Z.
# Layout: MEM_VARS + (token - 0xD0) * 4
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# VAR_INIT - Set all 26 variables to 0.
# Input:  None
# Output: None
# Clobbers: $t0, $t1
# -----------------------------------------------------------------------
VAR_INIT:
    la      $t0, MEM_VARS       # Load base address of variables array
    addiu   $t1, $zero, 26      # Initialize counter to 26 variables

VAR_INIT_LOOP:
    sw      $zero, 0($t0)       # Clear current variable word to 0
    addiu   $t0, $t0, 4         # Advance pointer to next word (4 bytes)
    addiu   $t1, $t1, -1        # Decrement counter
    bne     $t1, $zero, VAR_INIT_LOOP # Loop if not all variables are cleared
    jr      $ra                 # Return to caller

VAR_GET:
    addiu   $t0, $a0, -208
    sll     $t0, $t0, 2
    la      $t1, MEM_VARS
    addu    $t1, $t1, $t0
    lw      $v0, 0($t1)
    jr      $ra

VAR_SET:
    addiu   $t0, $a0, -208
    sll     $t0, $t0, 2
    la      $t1, MEM_VARS
    addu    $t1, $t1, $t0
    sw      $a1, 0($t1)
    jr      $ra

MUL16:
    mult    $a0, $a1
    mflo    $v0
    andi    $v0, $v0, 0xFFFF
    jr      $ra

DIV16:
    beq     $a1, $zero, DIV16_BY_ZERO
    divu    $a0, $a1
    mflo    $v0
    andi    $v0, $v0, 0xFFFF
    jr      $ra
DIV16_BY_ZERO:
    ori     $v0, $zero, 0xFFFF
    jr      $ra

MOD16:
    beq     $a1, $zero, MOD16_BY_ZERO
    divu    $a0, $a1
    mfhi    $v0
    andi    $v0, $v0, 0xFFFF
    jr      $ra
MOD16_BY_ZERO:
    andi    $v0, $a0, 0xFFFF
    jr      $ra

EVAL_EXPR:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)
    jal     EVAL_TERM
    addu    $s0, $v0, $zero
EE_LOOP:
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)
    lbu     $t1, 0($t0)
    addiu   $t2, $zero, 43
    beq     $t1, $t2, EE_ADD
    addiu   $t2, $zero, 45
    beq     $t1, $t2, EE_SUB
    addu    $v0, $s0, $zero
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra
EE_ADD:
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    jal     EVAL_TERM
    addu    $s0, $s0, $v0
    j       EE_LOOP
EE_SUB:
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    jal     EVAL_TERM
    subu    $s0, $s0, $v0
    j       EE_LOOP

EVAL_TERM:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)
    jal     EVAL_FACTOR
    addu    $s0, $v0, $zero
ET_LOOP:
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)
    lbu     $t1, 0($t0)
    addiu   $t2, $zero, 42
    beq     $t1, $t2, ET_MUL
    addiu   $t2, $zero, 47
    beq     $t1, $t2, ET_DIV
    addu    $v0, $s0, $zero
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra
ET_MUL:
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    jal     EVAL_FACTOR
    addu    $a0, $s0, $zero
    addu    $a1, $v0, $zero
    jal     MUL16
    addu    $s0, $v0, $zero
    j       ET_LOOP
ET_DIV:
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    jal     EVAL_FACTOR
    addu    $a0, $s0, $zero
    addu    $a1, $v0, $zero
    jal     DIV16
    addu    $s0, $v0, $zero
    j       ET_LOOP

EVAL_FACTOR:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)
    lbu     $s1, 0($s0)
    addiu   $t0, $zero, 192
    bne     $s1, $t0, EF_NOT_NUM
    lbu     $t1, 1($s0)
    lbu     $t2, 2($s0)
    sll     $t2, $t2, 8
    or      $v0, $t1, $t2
    addiu   $s0, $s0, 3
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    j       EF_DONE
EF_NOT_NUM:
    addiu   $t0, $zero, 208
    slt     $t1, $s1, $t0
    bne     $t1, $zero, EF_NOT_VAR
    addiu   $t0, $zero, 234
    slt     $t1, $s1, $t0
    beq     $t1, $zero, EF_NOT_VAR
    addu    $a0, $s1, $zero
    jal     VAR_GET
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    j       EF_DONE
EF_NOT_VAR:
    addiu   $t0, $zero, 40
    bne     $s1, $t0, EF_NOT_PAREN
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    jal     EVAL_EXPR
    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)
    addiu   $s0, $s0, 1
    sw      $s0, 0($t0)
    j       EF_DONE
EF_NOT_PAREN:
    addiu   $t0, $zero, 45
    bne     $s1, $t0, EF_ERR
    addiu   $s0, $s0, 1
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    jal     EVAL_FACTOR
    nor     $v0, $v0, $zero
    addiu   $v0, $v0, 1
    j       EF_DONE
EF_ERR:
    addu    $v0, $zero, $zero
EF_DONE:
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    sw      $s2, 8($sp)

    jal     EVAL_EXPR           # Evaluate left side expression, result in $v0
    addu    $s0, $v0, $zero     # $s0 = left side result

    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # Load token pointer
    lbu     $s1, 0($t0)         # $s1 = operator token
    
    addiu   $t0, $t0, 1         # Advance past operator
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)

    jal     EVAL_EXPR           # Evaluate right side expression, result in $v0
    addu    $s2, $v0, $zero     # $s2 = right side result

    # Compare 32-bit two's complement (unary minus and FREE stay full-width)

    # Let's perform comparisons based on $s1 (operator token)
    
    # 1) '=' (0x3D = 61)
    addiu   $t0, $zero, 61
    beq     $s1, $t0, EC_EQ

    # 2) '<>' (0xB0 = 176)
    addiu   $t0, $zero, 176
    beq     $s1, $t0, EC_NE

    # 3) '<' (0x3C = 60)
    addiu   $t0, $zero, 60
    beq     $s1, $t0, EC_LT

    # 4) '>' (0x3E = 62)
    addiu   $t0, $zero, 62
    beq     $s1, $t0, EC_GT

    # 5) '<=' (0xB1 = 177)
    addiu   $t0, $zero, 177
    beq     $s1, $t0, EC_LE

    # 6) '>=' (0xB2 = 178)
    addiu   $t0, $zero, 178
    beq     $s1, $t0, EC_GE

    # Unknown operator, return 0 (false)
    j       EC_FALSE

EC_EQ:
    beq     $s0, $s2, EC_TRUE
    j       EC_FALSE

EC_NE:
    bne     $s0, $s2, EC_TRUE
    j       EC_FALSE

EC_LT:
    slt     $t0, $s0, $s2
    bne     $t0, $zero, EC_TRUE
    j       EC_FALSE

EC_GT:
    slt     $t0, $s2, $s0
    bne     $t0, $zero, EC_TRUE
    j       EC_FALSE

EC_LE:
    slt     $t0, $s2, $s0
    beq     $t0, $zero, EC_TRUE
    j       EC_FALSE

EC_GE:
    slt     $t0, $s0, $s2
    beq     $t0, $zero, EC_TRUE
    j       EC_FALSE

EC_TRUE:
    addiu   $v0, $zero, 1       # Return 1
    j       EC_DONE

EC_FALSE:
    addu    $v0, $zero, $zero   # Return 0

EC_DONE:
    lw      $s2, 8($sp)
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra
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

# Stubs replaced by later command checkboxes
DO_LET:
DO_GOTO:
DO_GOSUB:
DO_IF:
DO_INPUT:
DO_RETURN:
DO_END:
    j       REPL
DO_LIST:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    jal     CMD_LIST
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL
DO_RUN:
DO_NEW:
DO_EXIT:
DO_REM:
    j       REPL
DO_FREE:
    j       REPL

REPL_STORE_LINE:
    jal     LINE_STORE
    j       REPL

REPL_LOOP_DONE:
    j       REPL

REPL_SYNTAX_ERROR:
    la      $a0, MSG_ERROR
    jal     PRINT_STR
    j       REPL
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
