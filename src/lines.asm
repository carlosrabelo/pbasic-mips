# lines.asm - Line storage for PBasic (MIPS)
# -----------------------------------------------------------------------
# Handles the linked list of tokenized BASIC lines in the program memory.
# Node format:
#   [4 bytes: next_ptr (32-bit absolute address, 0x00000000 = end)]
#   [2 bytes: line number (16-bit little-endian)]
#   [N bytes: tokens]
#   [1 byte : 0x00 terminator]
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# PROG_INIT
# -----------------------------------------------------------------------
# Description: Initializes program memory with a sentinel (null pointer).
# -----------------------------------------------------------------------
PROG_INIT:
    la      $t0, MEM_PROG_START
    addiu   $t1, $zero, 16384       # 53248 = 16384*3 + 4096 (fits addiu)
    addiu   $t1, $t1, 16384
    addiu   $t1, $t1, 16384
    addiu   $t1, $t1, 4096
    addu    $t1, $t0, $t1
    la      $t2, MEM_PROG_LIMIT
    sw      $t1, 0($t2)             # Limit = start + 52 KB

    sw      $zero, 0($t0)           # Write 32-bit sentinel (0x00000000)
    addiu   $t0, $t0, 4             # Advance pointer past sentinel
    la      $t2, MEM_PROG_END
    sw      $t0, 0($t2)
    jr      $ra

# -----------------------------------------------------------------------
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
