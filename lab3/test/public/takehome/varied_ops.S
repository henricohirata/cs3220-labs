#*****************************************************************************
# varied_ops.S
#-----------------------------------------------------------------------------
#
# Varied-operand DIV/MULT take-home sample.
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
    li x3, 2 # gp=2: hang before/inside burst means a deadlock
burst:
    lw x29, 0(x5) # op0: load ALUOP
    lw x30, 4(x5) # op0: load OP1
    lw x31, 8(x5) # op0: load OP2
    sw x27, 12(x5) # op0: store result (DIV  9.0 / 3.0  = 3.0)
    lw x29, 16(x5) # op1: load ALUOP
    lw x30, 20(x5) # op1: load OP1
    lw x31, 24(x5) # op1: load OP2
    sw x27, 28(x5) # op1: store result (MULT 6.0 * 7.0  = 42.0)
    lw x29, 32(x5) # op2: load ALUOP
    lw x30, 36(x5) # op2: load OP1
    lw x31, 40(x5) # op2: load OP2
    sw x27, 44(x5) # op2: store result (DIV 20.0 / 8.0  = 2.5)
    lw x29, 48(x5) # op3: load ALUOP
    lw x30, 52(x5) # op3: load OP1
    lw x31, 56(x5) # op3: load OP2
    sw x27, 60(x5) # op3: store result (MULT 1.25 * 4.0 = 5.0)
    lw x29, 64(x5) # op4: load ALUOP
    lw x30, 68(x5) # op4: load OP1
    lw x31, 72(x5) # op4: load OP2
    sw x27, 76(x5) # op4: store result (DIV 49.0 / 7.0  = 7.0)
    li x3, 3 # check op0
    lw x21, 12(x5) # read back result
    lui x22, 0x40400 # expected DIV  9.0 / 3.0  = 3.0
    bne x21, x22, fail
    li x3, 4 # check op1
    lw x21, 28(x5) # read back result
    lui x22, 0x42280 # expected MULT 6.0 * 7.0  = 42.0
    bne x21, x22, fail
    li x3, 5 # check op2
    lw x21, 44(x5) # read back result
    lui x22, 0x40200 # expected DIV 20.0 / 8.0  = 2.5
    bne x21, x22, fail
    li x3, 6 # check op3
    lw x21, 60(x5) # read back result
    lui x22, 0x40a00 # expected MULT 1.25 * 4.0 = 5.0
    bne x21, x22, fail
    li x3, 7 # check op4
    lw x21, 76(x5) # read back result
    lui x22, 0x40e00 # expected DIV 49.0 / 7.0  = 7.0
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
    .word 0x00000001  # ALUOP (DIV  9.0 / 3.0  = 3.0)
    .word 0x41100000  # OP1
    .word 0x40400000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000002  # ALUOP (MULT 6.0 * 7.0  = 42.0)
    .word 0x40c00000  # OP1
    .word 0x40e00000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 20.0 / 8.0  = 2.5)
    .word 0x41a00000  # OP1
    .word 0x41000000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000002  # ALUOP (MULT 1.25 * 4.0 = 5.0)
    .word 0x3fa00000  # OP1
    .word 0x40800000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 49.0 / 7.0  = 7.0)
    .word 0x42440000  # OP1
    .word 0x40e00000  # OP2
    .word 0x00000000  # result slot
