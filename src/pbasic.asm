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
    sb      $t2, 0($t1)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, 1
    j       TOK_LOOP

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
