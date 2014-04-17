# math.asm - Core mathematical primitives for PBasic (MIPS)
# -----------------------------------------------------------------------
# Implements 16-bit integer multiplication, division, and modulo.
# These are pure functions independent of the parser.
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# MUL16 - Unsigned 16-bit multiply.
# Input:  $a0 = op1, $a1 = op2
# Output: $v0 = (op1 * op2) & 0xFFFF (lower 16 bits)
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
MUL16:
    mult    $a0, $a1            # Multiply $a0 and $a1 (native instruction)
    mflo    $v0                 # Get lower 32 bits of result (native instruction)
    andi    $v0, $v0, 0xFFFF    # Mask to 16-bit unsigned integer (native instruction)
    jr      $ra                 # Return to caller

# -----------------------------------------------------------------------
# DIV16 - Unsigned 16-bit divide.
# Input:  $a0 = dividend, $a1 = divisor
# Output: $v0 = quotient, or 0xFFFF if division by zero
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
DIV16:
    beq     $a1, $zero, DIV16_BY_ZERO # Check for division by zero (native instruction)
    divu    $a0, $a1            # Unsigned division (native instruction)
    mflo    $v0                 # Get quotient (native instruction)
    andi    $v0, $v0, 0xFFFF    # Mask to 16-bit unsigned integer (native instruction)
    jr      $ra                 # Return to caller

DIV16_BY_ZERO:
    ori     $v0, $zero, 0xFFFF  # Return 65535 (0xFFFF) on division by zero
    jr      $ra                 # Return to caller

# -----------------------------------------------------------------------
# MOD16 - Unsigned 16-bit modulo.
# Input:  $a0 = dividend, $a1 = divisor
# Output: $v0 = remainder (dividend % divisor), or dividend if division by zero
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
MOD16:
    beq     $a1, $zero, MOD16_BY_ZERO # If divisor is 0, return dividend
    divu    $a0, $a1            # Unsigned division (native instruction)
    mfhi    $v0                 # Get remainder (native instruction)
    andi    $v0, $v0, 0xFFFF    # Mask to 16-bit unsigned integer (native instruction)
    jr      $ra                 # Return to caller

MOD16_BY_ZERO:
    andi    $v0, $a0, 0xFFFF    # Return masked dividend
    jr      $ra                 # Return to caller

# -----------------------------------------------------------------------
# RAND16 - Pseudo-random number generator (16-bit LCG).
# Algorithm: seed = (seed * 5 + 2971) & 0xFFFF
# Output: $v0 = new random number (16-bit)
# Clobbers: $t0, $t1, $t2
# -----------------------------------------------------------------------
RAND16:
    la      $t0, MEM_RAND_SEED  # Get address of the random seed
    lw      $t1, 0($t0)         # Load seed
    sll     $t2, $t1, 2         # $t2 = seed * 4
    addu    $t1, $t2, $t1       # $t1 = seed * 5
    addiu   $t1, $t1, 2971      # $t1 = seed * 5 + 2971
    andi    $t1, $t1, 0xFFFF    # Mask to 16-bit
    sw      $t1, 0($t0)         # Save new seed
    addu    $v0, $t1, $zero     # Output in $v0
    jr      $ra                 # Return to caller

