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
    addiu   $v0, $zero, 10
    syscall
