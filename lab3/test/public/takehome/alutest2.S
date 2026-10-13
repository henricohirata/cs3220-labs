# See LICENSE for license details.

#*****************************************************************************
# lw.S
#-----------------------------------------------------------------------------
#
# Test lw instruction.
#

#include "riscv_test.h"
#include "test_macros.h"


RVTEST_CODE_BEGIN

  # ALU operands loading

  TEST_CASE( 3, x14, 0x3f800000, \
    la x10, tdat3; \
    la x1, tdat1; \
    la x9, tdat2; \
    la x11, tdat4; \
    lw x29, 0(x10); \
    lw x30, 0(x1); \
    lw x31, 0(x9); \
    sw x27, 0(x11); \
    lw x14, 0(x11); \
  )

  TEST_CASE( 4, x14, 0x40c80000, \
    la x10, tdat7; \
    la x1, tdat5; \
    la x9, tdat6; \
    la x11, tdat8; \
    lw x29, 0(x10); \
    lw x30, 0(x1); \
    lw x31, 0(x9); \
    sw x27, 0(x11); \
    lw x14, 0(x11); \
  )




  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

tdat:
tdat1:  .word 0x3fc00000
tdat2:  .word 0x3fc00000
tdat3:  .word 0x00000001
tdat4:  .word 0x00000000
tdat5:  .word 0x40200000
tdat6:  .word 0x40200000
tdat7:  .word 0x00000002
tdat8:  .word 0x00000000
tdat9:  .word 0x00000000
tdat10: .word 0x00000000
tdat11: .word 0x00000000
tdat12: .word 0x00000000

RVTEST_DATA_END