# expr.asm - Expression evaluator for PBasic (MIPS)
# -----------------------------------------------------------------------
# Recursive descent parser with standard precedence:
#   expr   = term (('+' | '-') term)*
#   term   = factor (('*' | '/') factor)*
#   factor = number | variable | '(' expr ')' | '-' factor
#
# Uses MEM_TOKEN_PTR as the token stream position.
# All arithmetic is 16-bit signed/unsigned (depending on context).
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# EVAL_EXPR - Evaluate an expression (handles + and -).
# Input:  None (uses MEM_TOKEN_PTR)
# Output: $v0 = evaluated value (16-bit)
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
EVAL_EXPR:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)
    
    jal     EVAL_TERM           # Evaluate first term, result in $v0
    addu    $s0, $v0, $zero     # Accumulated value in $s0

EE_LOOP:
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # Load current token pointer
    lbu     $t1, 0($t0)         # Read current token byte
    
    addiu   $t2, $zero, 43      # '+' ASCII is 43
    beq     $t1, $t2, EE_ADD
    
    addiu   $t2, $zero, 45      # '-' ASCII is 45
    beq     $t1, $t2, EE_SUB
    
    # Neither '+' nor '-', return current accumulated value in $v0
    addu    $v0, $s0, $zero
    
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra

EE_ADD:
    # Advance token pointer past '+'
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    
    jal     EVAL_TERM           # Evaluate next term, result in $v0
    addu    $s0, $s0, $v0       # Accumulated value = $s0 + $v0
    j       EE_LOOP

EE_SUB:
    # Advance token pointer past '-'
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    
    jal     EVAL_TERM           # Evaluate next term, result in $v0
    subu    $s0, $s0, $v0       # Accumulated value = $s0 - $v0
    j       EE_LOOP

# -----------------------------------------------------------------------
# EVAL_TERM - Evaluate a term (handles * and /).
# Input:  None (uses MEM_TOKEN_PTR)
# Output: $v0 = evaluated value (16-bit)
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
EVAL_TERM:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)
    
    jal     EVAL_FACTOR         # Evaluate first factor, result in $v0
    addu    $s0, $v0, $zero     # Accumulated value in $s0

ET_LOOP:
    la      $t0, MEM_TOKEN_PTR
    lw      $t0, 0($t0)         # Load current token pointer
    lbu     $t1, 0($t0)         # Read current token byte
    
    addiu   $t2, $zero, 42      # '*' ASCII is 42
    beq     $t1, $t2, ET_MUL
    
    addiu   $t2, $zero, 47      # '/' ASCII is 47
    beq     $t1, $t2, ET_DIV
    
    # Neither '*' nor '/', return accumulated value in $v0
    addu    $v0, $s0, $zero
    
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra

ET_MUL:
    # Advance token pointer past '*'
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    
    jal     EVAL_FACTOR         # Evaluate next factor, result in $v0
    
    # Prepare arguments for MUL16 (op1=$s0, op2=$v0)
    addu    $a0, $s0, $zero
    addu    $a1, $v0, $zero
    jal     MUL16               # Call MUL16, result in $v0
    addu    $s0, $v0, $zero     # Save result back to accumulated value
    j       ET_LOOP

ET_DIV:
    # Advance token pointer past '/'
    addiu   $t0, $t0, 1
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)
    
    jal     EVAL_FACTOR         # Evaluate next factor, result in $v0
    
    # Prepare arguments for DIV16 (dividend=$s0, divisor=$v0)
    addu    $a0, $s0, $zero
    addu    $a1, $v0, $zero
    jal     DIV16               # Call DIV16, result in $v0
    addu    $s0, $v0, $zero     # Save result back to accumulated value
    j       ET_LOOP

# -----------------------------------------------------------------------
# EVAL_FACTOR - Evaluate a factor (number, variable, parens, functions).
# Input:  None (uses MEM_TOKEN_PTR)
# Output: $v0 = evaluated value (16-bit)
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
EVAL_FACTOR:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)

    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)         # Load current token pointer
    lbu     $s1, 0($s0)         # Read current token byte

    # --- Check for number literal (0xC0) ---
    addiu   $t0, $zero, 192     # 0xC0 in decimal is 192
    bne     $s1, $t0, EF_NOT_NUM

    # Number literal: 0xC0 lo hi
    lbu     $t1, 1($s0)         # Load low byte
    lbu     $t2, 2($s0)         # Load high byte
    sll     $t2, $t2, 8
    or      $v0, $t1, $t2       # $v0 = (high << 8) | low
    
    addiu   $s0, $s0, 3         # Advance token pointer past 0xC0 lo hi
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    j       EF_DONE

EF_NOT_NUM:
    # --- Check for FREE function (0xA0) ---
    addiu   $t0, $zero, 160     # 0xA0 in decimal is 160
    bne     $s1, $t0, EF_NOT_FREE

    addiu   $s0, $s0, 1         # Advance pointer past FREE token
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    la      $t0, MEM_PROG_LIMIT
    lw      $t0, 0($t0)         # First byte after the 52 KB buffer
    la      $t1, MEM_PROG_END
    lw      $t1, 0($t1)         # Current program end
    subu    $v0, $t0, $t1       # $v0 = free bytes
    j       EF_DONE

EF_NOT_FREE:
    # --- Check for RND function (0xA1) ---
    addiu   $t0, $zero, 161     # 0xA1 in decimal is 161
    bne     $s1, $t0, EF_NOT_RND

    addiu   $s0, $s0, 1         # Advance pointer past RND token
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    jal     EVAL_FACTOR         # Evaluate argument, result in $v0
    beq     $v0, $zero, EF_RND_ZERO

    # $s1 will hold the argument (limit X)
    addu    $s1, $v0, $zero
    
    jal     RAND16              # Get new random number in $v0
    
    addu    $a0, $v0, $zero     # dividend = random number
    addu    $a1, $s1, $zero     # divisor = X
    jal     MOD16               # result in $v0 (random % X)
    addiu   $v0, $v0, 1         # (random % X) + 1
    andi    $v0, $v0, 0xFFFF    # Mask to 16-bit
    j       EF_DONE

EF_RND_ZERO:
    jal     RAND16              # Just return raw random number in $v0
    j       EF_DONE

EF_NOT_RND:
    # --- Check for ABS function (0xA2) ---
    addiu   $t0, $zero, 162     # 0xA2 in decimal is 162
    bne     $s1, $t0, EF_NOT_ABS

    addiu   $s0, $s0, 1         # Advance pointer past ABS token
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    jal     EVAL_FACTOR         # Evaluate argument, result in $v0
    andi    $t0, $v0, 0x8000    # Check sign bit (bit 15)
    beq     $t0, $zero, EF_DONE # If zero, it's positive, return as is

    # Negate $v0 (32-bit two's complement; do not mask — FREE is 32-bit)
    nor     $v0, $v0, $zero
    addiu   $v0, $v0, 1
    j       EF_DONE

EF_NOT_ABS:
    # --- Check for variable token (0xD0 - 0xE9) ---
    addiu   $t0, $zero, 208     # 0xD0 in decimal is 208
    slt     $t1, $s1, $t0       # $t1 = 1 if token < 0xD0
    bne     $t1, $zero, EF_NOT_VAR

    addiu   $t0, $zero, 234     # 0xEA in decimal is 234
    slt     $t1, $s1, $t0       # $t1 = 1 if token < 0xEA
    beq     $t1, $zero, EF_NOT_VAR

    # Variable token: Call VAR_GET
    addu    $a0, $s1, $zero     # Variable token in $a0
    jal     VAR_GET             # Get value in $v0
    
    addiu   $s0, $s0, 1         # Advance past variable token
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)
    j       EF_DONE

EF_NOT_VAR:
    # --- Check for '(' token ---
    addiu   $t0, $zero, 40      # '(' ASCII is 40
    bne     $s1, $t0, EF_NOT_PAREN

    addiu   $s0, $s0, 1         # Advance past '('
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    jal     EVAL_EXPR           # Evaluate nested expression recursively, result in $v0
    
    # We assume next token is ')' and advance past it
    la      $t0, MEM_TOKEN_PTR
    lw      $s0, 0($t0)
    addiu   $s0, $s0, 1         # Advance past ')'
    sw      $s0, 0($t0)
    j       EF_DONE

EF_NOT_PAREN:
    # --- Check for unary '-' ---
    addiu   $t0, $zero, 45      # '-' ASCII is 45
    bne     $s1, $t0, EF_ERR

    addiu   $s0, $s0, 1         # Advance past '-'
    la      $t0, MEM_TOKEN_PTR
    sw      $s0, 0($t0)

    jal     EVAL_FACTOR         # Evaluate factor to negate recursively, result in $v0
    nor     $v0, $v0, $zero     # Negate (32-bit two's complement)
    addiu   $v0, $v0, 1
    j       EF_DONE

EF_ERR:
    # Default return 0 on syntax error
    addu    $v0, $zero, $zero

EF_DONE:
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra

# -----------------------------------------------------------------------
# EVAL_COND - Evaluate a condition (expr relop expr).
# Input:  None (uses MEM_TOKEN_PTR)
# Output: $v0 = 1 if true, 0 if false
# Clobbers: None (except $v0 and HI/LO registers)
# -----------------------------------------------------------------------
EVAL_COND:
    addiu   $sp, $sp, -24
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
