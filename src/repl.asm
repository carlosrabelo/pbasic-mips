# repl.asm - Read-Eval-Print Loop and execution control (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# REPL - Read-Eval-Print Loop
# Description:
#   Main interactive loop. Prompts the user, reads input, and loops.
# -----------------------------------------------------------------------
REPL:
    la      $t0, MEM_RUN_FLAG
    lw      $t0, 0($t0)         # Load run flag
    bnez    $t0, RUN_NEXT       # If running a program, go straight to execute next line

    # Print prompt "> "
    la      $a0, STR_PROMPT
    jal     PRINT_STR

    # Read user input into MEM_INPUT_BUF
    jal     READ_LINE

    # Convert input text into Tokens
    jal     TOKENIZE

    # Initialize MEM_TOKEN_PTR to point to MEM_TOKEN_BUF
    la      $t0, MEM_TOKEN_BUF
    la      $t1, MEM_TOKEN_PTR
    sw      $t0, 0($t1)

    # Jump to the dispatch engine
    j       REPL_DISPATCH

REPL_STORE_LINE:
    jal     LINE_STORE
    j       REPL

REPL_LOOP_DONE:
    la      $t0, MEM_RUN_FLAG
    lw      $t0, 0($t0)         # Load run flag
    bnez    $t0, RUN_NEXT       # If running, go execute next line
    j       REPL

REPL_SYNTAX_ERROR:
    la      $a0, MSG_ERROR
    jal     PRINT_STR
    j       REPL

# -----------------------------------------------------------------------
# RUN_NEXT - Advance execution to the next program line
# Input:  None
# Output: None
# Clobbers: $t0, $t1, $t2
# -----------------------------------------------------------------------
RUN_NEXT:
    # Save the return address register because we are going to use 'jal'
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)

    # Invoke non-blocking break key check
    jal     CHECK_BREAK         # Returns $v0 = 1 if break key is pressed, 0 otherwise

    # Restore the return address register
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4

    # If $v0 is zero, continue execution normally
    beq     $v0, $zero, RN_CONTINUE

    # Break requested! Turn off the execution state and return to interactive prompt
    la      $t0, MEM_RUN_FLAG
    sw      $zero, 0($t0)       # Clear execution flag
    j       REPL                # Return straight to prompt

RN_CONTINUE:
    la      $t0, MEM_LINE_PTR
    lw      $t0, 0($t0)         # $t0 = current line node address
    lw      $t1, 0($t0)         # $t1 = next node address (next_ptr)

    # Check if next node's next_ptr is null (sentinel node)
    lw      $t2, 0($t1)         # $t2 = next_ptr of next node
    beqz    $t2, RUN_END        # If null, end of program

    # Update MEM_LINE_PTR to next node
    la      $t0, MEM_LINE_PTR
    sw      $t1, 0($t0)

    # Set MEM_TOKEN_PTR to point to the tokens of the new node (node + 6)
    addiu   $t1, $t1, 6
    la      $t0, MEM_TOKEN_PTR
    sw      $t1, 0($t0)

    # Dispatch tokens
    j       REPL_DISPATCH

# -----------------------------------------------------------------------
# RUN_END - Turn off execution mode and return to interactive REPL
# Input:  None
# Output: None
# Clobbers: $t0
# -----------------------------------------------------------------------
RUN_END:
    la      $t0, MEM_RUN_FLAG
    sw      $zero, 0($t0)       # Clear execution flag
    j       REPL                # Return to interactive prompt
