# io.asm - Base I/O routines for PBasic MIPS
# -----------------------------------------------------------------------
# Provides the low-level communication between the interpreter and the
# MARS emulator console using standard MIPS syscalls.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# INCHAR - Read a single character from the console
# -----------------------------------------------------------------------
# Description:
#   Halts execution and waits for the user to input a single character
#   from the MARS keyboard console.
#
# Input: None
# Output: $v0 (The ASCII value of the character read)
# Clobbers: $v0
# -----------------------------------------------------------------------
INCHAR:
    li      $v0, 12         # MARS syscall 12: Read Character
    syscall                 # Execute syscall. Character is returned in $v0.
    jr      $ra             # Return to caller

# -----------------------------------------------------------------------
# CHECK_BREAK - Check if a break key (Ctrl+C, ESC, q, Q) is pressed (non-blocking)
# -----------------------------------------------------------------------
# Output:
#   $v0 = 1 if break requested, 0 otherwise
# Clobbers:
#   $t0, $t1, $v0
# -----------------------------------------------------------------------
CHECK_BREAK:
    lui     $t0, 0xFFFF         # $t0 = 0xFFFF0000 (Keyboard Receiver Control Register)
    lw      $t1, 0($t0)         # Read the control word from MMIO
    andi    $t1, $t1, 1         # Check bit 0 (ready bit)
    beq     $t1, $zero, CB_NONE # If ready bit is 0, no key has been pressed

    lw      $t1, 4($t0)         # Read the ASCII code from Keyboard Receiver Data Register (0xFFFF0004)

    # Compare character against the cancel keys
    addiu   $v0, $zero, 81      # $v0 = 81 (ASCII for 'Q')
    beq     $t1, $v0, CB_YES
    addiu   $v0, $zero, 113     # $v0 = 113 (ASCII for 'q')
    beq     $t1, $v0, CB_YES
    addiu   $v0, $zero, 27      # $v0 = 27 (ASCII for ESC)
    beq     $t1, $v0, CB_YES
    addiu   $v0, $zero, 3       # $v0 = 3 (ASCII for Ctrl+C)
    beq     $t1, $v0, CB_YES

CB_NONE:
    add     $v0, $zero, $zero   # Return 0 (no break)
    jr      $ra                 # Return

CB_YES:
    addiu   $v0, $zero, 1       # Return 1 (break requested)
    jr      $ra                 # Return

# -----------------------------------------------------------------------
# OUTCHAR - Print a single character to the console
# -----------------------------------------------------------------------
# Description:
#   Prints the ASCII character passed in register $a0 to the MARS console.
#
# Input: $a0 (The ASCII character to print)
# Output: None
# Clobbers: $v0
# -----------------------------------------------------------------------
OUTCHAR:
    li      $v0, 11         # MARS syscall 11: Print Character
    syscall                 # Execute syscall. Prints character in $a0.
    jr      $ra             # Return to caller

# -----------------------------------------------------------------------
# PRINT_STR - Print a null-terminated string
# -----------------------------------------------------------------------
# Description:
#   Prints the null-terminated string located at address $a0.
#
# Input: $a0 (Address of string)
# Output: None
# Clobbers: $v0
# -----------------------------------------------------------------------
PRINT_STR:
    li      $v0, 4          # SPIM syscall 4: Print String
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# PRINT_NUMBER - Print an integer
# -----------------------------------------------------------------------
# Description:
#   Prints the 32-bit integer passed in $a0.
#
# Input: $a0 (Integer to print)
# Output: None
# Clobbers: $v0
# -----------------------------------------------------------------------
PRINT_NUMBER:
    li      $v0, 1          # SPIM syscall 1: Print Integer
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# PRINT_CRLF - Print a newline
# -----------------------------------------------------------------------
# Description:
#   Prints a CR/LF (newline) sequence to the console.
#
# Input: None
# Output: None
# Clobbers: $v0, $a0
# -----------------------------------------------------------------------
PRINT_CRLF:
    la      $a0, STR_CRLF
    li      $v0, 4          # SPIM syscall 4: Print String
    syscall
    jr      $ra

# -----------------------------------------------------------------------
# READ_LINE - Read input from console into input buffer
# -----------------------------------------------------------------------
# Description:
#   Reads a line of text from the console into MEM_INPUT_BUF,
#   strips the trailing newline, and converts lowercase to uppercase.
#
# Input: None
# Output: None
# Clobbers: $v0, $a0, $a1, $t0, $t1
# -----------------------------------------------------------------------

READ_LINE:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    la      $a0, MEM_INPUT_BUF
    li      $a1, 127            # Max length (leaves room for null terminator)
    li      $v0, 8              # SPIM syscall 8: Read String
    syscall

    # Check if we read anything or if it's EOF (an empty read on first char)
    la      $t0, MEM_INPUT_BUF
    lbu     $t1, 0($t0)
    beqz    $t1, READ_LINE_EOF

    # Post-process: remove newline (\n or \r) and convert to uppercase
READ_LINE_LOOP:
    lbu     $t1, 0($t0)
    beqz    $t1, READ_LINE_DONE

    # If it is newline (\n, ASCII 10), replace with \0 and terminate
    li      $t2, 10
    beq     $t1, $t2, RL_TRUNCATE

    # If it is carriage return (\r, ASCII 13), replace with \0 and terminate
    li      $t2, 13
    beq     $t1, $t2, RL_TRUNCATE

    # Check if char is 'a'-'z' (97 to 122)
    li      $v0, 97
    slt     $a1, $t1, $v0
    bne     $a1, $zero, READ_LINE_NEXT
    li      $v0, 122
    slt     $a1, $v0, $t1
    bne     $a1, $zero, READ_LINE_NEXT

    # Convert to uppercase
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
    li      $v0, 10             # Exit syscall if EOF
    syscall

# -----------------------------------------------------------------------
# PRINT_OK - Print "OK" message (MSG_OK already contains newline)
# Input:  None
# Output: None
# Clobbers: $v0, $a0
# -----------------------------------------------------------------------
PRINT_OK:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    
    la      $a0, MSG_OK
    jal     PRINT_STR
    
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $ra

