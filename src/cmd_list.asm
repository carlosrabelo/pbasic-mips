# cmd_list.asm - LIST command execution (MIPS)
# -----------------------------------------------------------------------

.text

# -----------------------------------------------------------------------
# DO_LIST - Prints all tokenized BASIC lines
# Input:  None
# Output: None
# Clobbers: None
# -----------------------------------------------------------------------
DO_LIST:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    jal     CMD_LIST
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    j       REPL
