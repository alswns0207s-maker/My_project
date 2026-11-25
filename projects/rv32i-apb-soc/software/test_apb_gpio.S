    .section .text
    .globl _start
_start:
    lui  x1, 0x10000
    lui  x2, 0x12345
    addi x2, x2, 0x678
    sw   x2, 0(x1)

    lui  x3, 0x20000
    addi x4, x0, 0xff
    sw   x0, 0(x3)
    sw   x4, 0x100(x3)

loop:
    lw   x5, 4(x3)
    sw   x5, 0x104(x3)
    jal  x0, loop
