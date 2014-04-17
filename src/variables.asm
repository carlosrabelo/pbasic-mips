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

# -----------------------------------------------------------------------
# VAR_GET - Read 32-bit variable value.
# Input:  $a0 = variable token (0xD0-0xE9)
# Output: $v0 = variable value (32-bit)
# Clobbers: $t0, $t1
# -----------------------------------------------------------------------
VAR_GET:
    addiu   $t0, $a0, -208      # Convert token (0xD0=208) to index (0-25)
    sll     $t0, $t0, 2         # Multiply index by 4 (4 bytes per variable)
    la      $t1, MEM_VARS       # Load base address of variables array
    addu    $t1, $t1, $t0       # Add offset to base address
    lw      $v0, 0($t1)         # Load the variable value
    jr      $ra                 # Return to caller

# -----------------------------------------------------------------------
# VAR_SET - Write 32-bit variable value.
# Input:  $a0 = variable token (0xD0-0xE9)
#         $a1 = 32-bit value to set
# Output: None
# Clobbers: $t0, $t1
# -----------------------------------------------------------------------
VAR_SET:
    addiu   $t0, $a0, -208      # Convert token (0xD0=208) to index (0-25)
    sll     $t0, $t0, 2         # Multiply index by 4 (4 bytes per variable)
    la      $t1, MEM_VARS       # Load base address of variables array
    addu    $t1, $t1, $t0       # Add offset to base address
    sw      $a1, 0($t1)         # Store the value into the variable
    jr      $ra                 # Return to caller
