# strings.asm - Message strings and keyword data for PBasic (MIPS)
# -----------------------------------------------------------------------
# Defines all static text, error messages, and the keyword dictionaries
# used by the tokenizer and detokenizer.
# -----------------------------------------------------------------------

.data

# --- Messages ---
# Null-terminated strings printed to the TTY.
MSG_BANNER:     .asciiz "PBasic\n"
MSG_OK:         .asciiz "OK\n"
MSG_ERROR:      .asciiz "?SYNTAX ERROR\n"
MSG_NO_PROGRAM: .asciiz "?NO PROGRAM\n"
MSG_OUT_OF_MEMORY: .asciiz "?OUT OF MEMORY\n"

# --- Keywords for tokenizer (KW_*) ---
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

# --- Keyword display strings (PKWS_*) ---
# Used by PRINT_KEYWORD in detokenize.asm
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

# -----------------------------------------------------------------------
# PKW_TABLE - O(1) Lookup table for keyword strings (Tokens 0x80-0x8D)
# -----------------------------------------------------------------------
.align 2
PKW_TABLE:
    .word PKWS_LET            # 0x80
    .word PKWS_GOTO           # 0x81
    .word PKWS_GOSUB          # 0x82
    .word PKWS_PRINT          # 0x83
    .word PKWS_IF             # 0x84
    .word PKWS_INPUT          # 0x85
    .word PKWS_RETURN         # 0x86
    .word PKWS_END            # 0x87
    .word PKWS_LIST           # 0x88
    .word PKWS_RUN            # 0x89
    .word PKWS_NEW            # 0x8A
    .word PKWS_EXIT           # 0x8B
    .word PKWS_REM            # 0x8C
    .word PKWS_THEN           # 0x8D
