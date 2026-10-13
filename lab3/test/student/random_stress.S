#*****************************************************************************
# random_stress.S
#-----------------------------------------------------------------------------
#
# Randomized DIV/MULT stress test.
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
    sw x27, 12(x5) # op0: store result (DIV 1699656 / 3624 = 469)
    lw x29, 16(x5) # op1: load ALUOP
    lw x30, 20(x5) # op1: load OP1
    lw x31, 24(x5) # op1: load OP2
    sw x27, 28(x5) # op1: store result (DIV 336 / 28 = 12)
    lw x29, 32(x5) # op2: load ALUOP
    lw x30, 36(x5) # op2: load OP1
    lw x31, 40(x5) # op2: load OP2
    sw x27, 44(x5) # op2: store result (DIV 18680 / 80 = 233.5)
    lw x29, 48(x5) # op3: load ALUOP
    lw x30, 52(x5) # op3: load OP1
    lw x31, 56(x5) # op3: load OP2
    sw x27, 60(x5) # op3: store result (DIV 727605 / 6840 = 106.375)
    lw x29, 64(x5) # op4: load ALUOP
    lw x30, 68(x5) # op4: load OP1
    lw x31, 72(x5) # op4: load OP2
    sw x27, 76(x5) # op4: store result (MULT 67.75 * -2660 = -180215)
    lw x29, 80(x5) # op5: load ALUOP
    lw x30, 84(x5) # op5: load OP1
    lw x31, 88(x5) # op5: load OP2
    sw x27, 92(x5) # op5: store result (DIV -134130 / -680 = 197.25)
    lw x29, 96(x5) # op6: load ALUOP
    lw x30, 100(x5) # op6: load OP1
    lw x31, 104(x5) # op6: load OP2
    sw x27, 108(x5) # op6: store result (DIV 117906.25 / 1925 = 61.25)
    lw x29, 112(x5) # op7: load ALUOP
    lw x30, 116(x5) # op7: load OP1
    lw x31, 120(x5) # op7: load OP2
    sw x27, 124(x5) # op7: store result (MULT 5242 * -652.5 = -3420405)
    lw x29, 128(x5) # op8: load ALUOP
    lw x30, 132(x5) # op8: load OP1
    lw x31, 136(x5) # op8: load OP2
    sw x27, 140(x5) # op8: store result (DIV -286760 / -535 = 536)
    lw x29, 144(x5) # op9: load ALUOP
    lw x30, 148(x5) # op9: load OP1
    lw x31, 152(x5) # op9: load OP2
    sw x27, 156(x5) # op9: store result (MULT -31776 * 237.8125 = -7556730)
    li x3, 3 # check op0
    lw x21, 12(x5) # read back result
    lui x22, 0x43ea8 # expected DIV 1699656 / 3624 = 469
    bne x21, x22, fail
    li x3, 4 # check op1
    lw x21, 28(x5) # read back result
    lui x22, 0x41400 # expected DIV 336 / 28 = 12
    bne x21, x22, fail
    li x3, 5 # check op2
    lw x21, 44(x5) # read back result
    lui x22, 0x43698 # expected DIV 18680 / 80 = 233.5
    bne x21, x22, fail
    li x3, 6 # check op3
    lw x21, 60(x5) # read back result
    lui x22, 0x42d4c # expected DIV 727605 / 6840 = 106.375
    bne x21, x22, fail
    li x3, 7 # check op4
    lw x21, 76(x5) # read back result
    lui x22, 0xc8300 # expected MULT 67.75 * -2660 = -180215
    addi x22, x22, -576
    bne x21, x22, fail
    li x3, 8 # check op5
    lw x21, 92(x5) # read back result
    lui x22, 0x43454 # expected DIV -134130 / -680 = 197.25
    bne x21, x22, fail
    li x3, 9 # check op6
    lw x21, 108(x5) # read back result
    lui x22, 0x42750 # expected DIV 117906.25 / 1925 = 61.25
    bne x21, x22, fail
    li x3, 10 # check op7
    lw x21, 124(x5) # read back result
    lui x22, 0xca50c # expected MULT 5242 * -652.5 = -3420405
    addi x22, x22, 980
    bne x21, x22, fail
    li x3, 11 # check op8
    lw x21, 140(x5) # read back result
    lui x22, 0x44060 # expected DIV -286760 / -535 = 536
    bne x21, x22, fail
    li x3, 12 # check op9
    lw x21, 156(x5) # read back result
    lui x22, 0xcae6a # expected MULT -31776 * 237.8125 = -7556730
    addi x22, x22, -780
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
    .word 0x00000001  # ALUOP (DIV 1699656 / 3624 = 469)
    .word 0x49cf7a40  # OP1
    .word 0x45628000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 336 / 28 = 12)
    .word 0x43a80000  # OP1
    .word 0x41e00000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 18680 / 80 = 233.5)
    .word 0x4691f000  # OP1
    .word 0x42a00000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 727605 / 6840 = 106.375)
    .word 0x4931a350  # OP1
    .word 0x45d5c000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000002  # ALUOP (MULT 67.75 * -2660 = -180215)
    .word 0x42878000  # OP1
    .word 0xc5264000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV -134130 / -680 = 197.25)
    .word 0xc802fc80  # OP1
    .word 0xc42a0000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV 117906.25 / 1925 = 61.25)
    .word 0x47e64920  # OP1
    .word 0x44f0a000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000002  # ALUOP (MULT 5242 * -652.5 = -3420405)
    .word 0x45a3d000  # OP1
    .word 0xc4232000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000001  # ALUOP (DIV -286760 / -535 = 536)
    .word 0xc88c0500  # OP1
    .word 0xc405c000  # OP2
    .word 0x00000000  # result slot
    .word 0x00000002  # ALUOP (MULT -31776 * 237.8125 = -7556730)
    .word 0xc6f84000  # OP1
    .word 0x436dd000  # OP2
    .word 0x00000000  # result slot
