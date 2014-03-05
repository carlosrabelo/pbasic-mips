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

.text
.globl main

main:
    # SPIM and MARS initialize $sp on startup (MARS: 0x7FFFEFFC).
    # No manual stack initialization is required.
    jal     REPL
    j       HALT_LOOP

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
    j       REPL

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
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TOK_LOOP

TOK_DONE:
    sb      $zero, 0($t1)
    jr      $ra

# Stubs until later tokenizer checkboxes
TOK_NUMBER:
    addiu   $t0, $t0, 1
    j       TOK_LOOP

TOK_STRING:
    addiu   $t0, $t0, 1
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
