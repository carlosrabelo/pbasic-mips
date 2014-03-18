# main.asm - PBasic interpreter entry point (MIPS)
# -----------------------------------------------------------------------

.text
.globl main

# -----------------------------------------------------------------------
# START - System initialization routine
# -----------------------------------------------------------------------
main:
    # Print banner message upon startup
    la      $a0, MSG_BANNER
    li      $v0, 4
    syscall

    # SPIM and MARS initialize $sp on startup (MARS: 0x7FFFEFFC).
    # No manual stack initialization is required.

    # Initialize program memory (write sentinel to MEM_PROG_START)
    jal     PROG_INIT
    
    # Initialize all variables (A-Z)
    jal     VAR_INIT
    
    # Enter the main Read-Eval-Print Loop (Interactive prompt)
    jal     REPL
    j       HALT_LOOP
    
HALT_LOOP:
    # Exit syscall (10) for clean termination in MARS/SPIM
    li      $v0, 10
    syscall
