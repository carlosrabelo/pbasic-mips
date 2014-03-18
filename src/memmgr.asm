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
