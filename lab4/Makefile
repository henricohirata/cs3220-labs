
#
# DESCRIPTION: Verilator Example: Small Makefile
#
# This calls the object directory makefile.  That allows the objects to
# be placed in the "current directory" which simplifies the Makefile.
#
# Copyright 2003-2018 by Wilson Snyder. This program is free software; you can
# redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
#
######################################################################
# Check for sanity to avoid later confusion

.PHONY: default submit clean axis_data_fifo axi4_ram axi4_ram_complete_transaction axi4_ram_tests axi4_ram_burst axi4_ram_burst_sweep axi4_ram_burst_tests axi4_ram_burst_on_non_burst

ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

######################################################################

# This is intended to be a minimal example.  Before copying this to start a
# real project, it is better to start with a more complete example,
# e.g. examples/tracing_c.

# If $VERILATOR_ROOT isn't in the environment, we assume it is part of a
# package inatall, and verilator is in your path. Otherwise find the
# binary relative to $VERILATOR_ROOT (such as when inside the git sources).
ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
endif


PYTHON = python3

# ---------------------------------------------------------------------
# RTL under test.  Non-burst tests build axis_data_fifo.v / axi4_ram.v; burst
# tests build axi4_ram_burst.v.  The burst build pins two macros, because the
# two benches disagree about how many writes may be outstanding (non-burst
# CORNER 2 wants two, burst BC8/BC10 allow exactly one).
#
# Override on the command line to try another source, e.g.:
#   make axi4_ram AXI_RAM_SRC=other.v
# ---------------------------------------------------------------------
AXI_RAM_SRC        ?= axi4_ram.v
AXI_RAM_BURST_SRC  ?= axi4_ram_burst.v
AXI_RAM_BURST_DEFS ?= +define+AXI_RAM_MAX_BUFFER_DEPTH=1 +define+AXI_RAM_INVALID_READ_GUARD=0
VL_FLAGS_TEST_AXIS_FIFO += --exe -cc tb_axis_fifo.v --top-module tb_axis_fifo --trace --trace-structs
VL_FLAGS_TEST_AXI4_RAM += --exe -cc tb_axi4_ram.v --top-module tb_axi4_ram --trace --trace-structs --timing
VL_FLAGS_TEST_AXI4_RAM_BURST += --exe -cc tb_axi4_ram_burst.v --top-module tb_axi4_ram_burst --trace --trace-structs --timing
VL_FLAGS_TEST_AXI4_RAM_TESTS += --exe -cc tb_axi4_ram_tests.v --top-module tb_axi4_ram_tests --trace --trace-structs --timing
VL_FLAGS_TEST_AXI4_RAM_BURST_TESTS += --exe -cc tb_axi4_ram_burst_tests.v --top-module tb_axi4_ram_burst_tests --trace --trace-structs --timing
#VL_FLAGS += --assert -Wall -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
VL_FLAGS += --assert -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
CXXFLAGS += -DVCD_OUTPUT -DDPRINTF
#CXXFLAGS += -DVCD_OUTPUT 
LDFLAGS += 

default:
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXIS_FIFO) $(VL_FLAGS) test_axis_fifo.cpp axis_data_fifo.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axis_fifo.mk 
	@echo "-- RUN ---------------------"
	obj_dir/Vtb_axis_fifo
	@echo "-- DONE --------------------"
	
axis_data_fifo:
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXIS_FIFO) $(VL_FLAGS) test_axis_fifo.cpp axis_data_fifo.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axis_fifo.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vtb_axis_fifo > axis_data_fifo.log
	$(PYTHON) data_gen.py parse_log
	@echo "-- DONE --------------------"

# Umbrella: run every non-burst (single-beat) axi4_ram test in sequence.
axi4_ram: axi4_ram_complete_transaction axi4_ram_tests
	@echo "== axi4_ram: all non-burst tests complete =="

# Combined directed bench: edge + protocol-corner cases in one file,
# tb_axi4_ram_tests.v.  A correct implementation passes both halves.  The make
# step is non-fatal so the full report is always printed; the C++ driver's exit
# code follows the edge half only.
axi4_ram_tests:
	@echo "-- VERILATE (directed edge + corner tests) ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXI4_RAM_TESTS) $(VL_FLAGS) test_axi4_ram_tests.cpp $(AXI_RAM_SRC) -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axi4_ram_tests.mk
	@echo "-- RUN (directed edge + corner tests) ---------------------"
	@echo "   (PART A edge and PART B corners 1-3: a correct implementation passes all)"
	-obj_dir/Vtb_axi4_ram_tests
	@echo "-- DONE --------------------"

# Complete-transaction sweep: the HLS round-trip test (1024 single-beat
# write/read/compare).  This was the original `make axi4_ram`.
axi4_ram_complete_transaction:
	@echo "-- VERILATE (HLS round-trip sweep) -----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXI4_RAM) $(VL_FLAGS) test_axi4_ram.cpp $(AXI_RAM_SRC) axi4_tester_src_non_burst/*.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axi4_ram.mk
	@echo "-- RUN (HLS round-trip sweep) ---------------------"
	obj_dir/Vtb_axi4_ram
	@echo "-- DONE --------------------"

# Umbrella: run all axi4_ram_burst test cases (sweep + directed) in sequence.
axi4_ram_burst: axi4_ram_burst_sweep axi4_ram_burst_tests
	@echo "== axi4_ram_burst: all burst tests complete =="

# Combined directed burst bench: edge + protocol-corner cases in one file,
# tb_axi4_ram_burst_tests.v.  Non-fatal for the same reason as above.
axi4_ram_burst_tests:
	@echo "-- VERILATE (directed burst edge + corner tests) ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXI4_RAM_BURST_TESTS) $(VL_FLAGS) test_axi4_ram_burst_tests.cpp $(AXI_RAM_BURST_DEFS) $(AXI_RAM_BURST_SRC) -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axi4_ram_burst_tests.mk
	@echo "-- RUN (directed burst edge + corner tests) ---------------------"
	@echo "   (PART A BE1-BE8 and PART B BC1-BC10: a correct implementation passes all)"
	-obj_dir/Vtb_axi4_ram_burst_tests
	@echo "-- DONE --------------------"

# HLS burst sweep (randomized burst read/write/compare).
axi4_ram_burst_sweep:
	@echo "-- VERILATE (HLS burst sweep) ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXI4_RAM_BURST) $(VL_FLAGS) test_axi4_ram_burst.cpp $(AXI_RAM_BURST_DEFS) $(AXI_RAM_BURST_SRC) axi4_tester_src_burst/*.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axi4_ram_burst.mk
	@echo "-- RUN (HLS burst sweep) ---------------------"
	obj_dir/Vtb_axi4_ram_burst
	@echo "-- DONE --------------------"


axi4_ram_burst_on_non_burst:
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VL_FLAGS_TEST_AXI4_RAM_BURST) $(VL_FLAGS) test_axi4_ram_burst.cpp $(AXI_RAM_BURST_DEFS) $(AXI_RAM_BURST_SRC) axi4_tester_src_non_burst/*.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vtb_axi4_ram_burst.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vtb_axi4_ram_burst
	@echo "-- DONE --------------------"

submit: 
	@echo "-- ZIPPING ALL THE FILE ---------"
	zip submission.zip ./*.v ./*.h ./*.vh ./*.cpp

maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir *.log *.dmp *.vpd core trace.vcd
