# pbasic.asm - PBasic interpreter (monolith during pedagogical rebuild)
# -----------------------------------------------------------------------

.text
.globl main

main:
    # SPIM and MARS initialize $sp on startup.
    addiu   $v0, $zero, 10
    syscall
