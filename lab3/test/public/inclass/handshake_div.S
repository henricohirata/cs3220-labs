#*****************************************************************************
# handshake_div.S
#-----------------------------------------------------------------------------
#
# Single DIV handshake reference (in-class waveform).
#
.section .text
.globl _start
_start:
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0
    lui x5, 0x1 # x5 = data block base
    addi x5, x5, -2048
    li x3, 2 # gp=2: hang before handshake completes
    lw x29, 0(x5) # load ALUOP (DIV=1)
    lw x30, 4(x5) # load OP1 (3.0)
    nop
    nop
    lw x31, 8(x5) # load OP2 (1.5)
    sw x27, 12(x5) # store result to memory
    li x3, 3 # check result
    lw x21, 12(x5) # read back result
    lui x22, 0x40000 # expected 2.0
    bne x21, x22, fail
pass:
    li x3, 1
    nop
    nop
    nop
    nop
    j theend
fail:
    nop
    nop
    nop
    nop
    j theend
theend:
    nop
    nop
    nop
    nop

.section .data
.org 0x470  # data placed at 0x800 via link.ld
    .word 0x00000001  # ALUOP (DIV)
    .word 0x40400000  # OP1 (3.0)
    .word 0x3fc00000  # OP2 (1.5)
    .word 0x00000000  # result slot
