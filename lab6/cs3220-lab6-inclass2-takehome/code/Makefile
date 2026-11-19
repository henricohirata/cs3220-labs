
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

.PHONY: default help check_tools submit clean systolic_array systolic_array_nk systolic_array_axis

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


PYTHON = python
VL_FLAGS_TEST_SYSTOLIC_ARRAY+= --exe -cc systolic_array.v --top-module systolic_array --trace --trace-structs #--timing
VL_FLAGS_TEST_SYSTOLIC_ARRAY_AXIS+= --exe -cc systolic_array_axis.v --top-module systolic_array_axis --trace --trace-structs
#VL_FLAGS += --assert -Wall -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
VL_FLAGS += --assert -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
CXXFLAGS += -DVCD_OUTPUT -DDPRINTF
#CXXFLAGS += -DVCD_OUTPUT 
LDFLAGS += 

# default test parameters
ROWS = 4
COLS = 4
K = 4
NUM_TESTS = 10
SEED = 1
MULT_LAT = 3 
TEST_FILE = test_axis.cpp

# Catch misspelled settings such as rows=4 (they would otherwise be ignored silently)
BAD_SETTINGS := $(filter-out ROWS=% COLS=% K=% NUM_TESTS=% SEED=% MULT_LAT=% VERILATOR_ROOT=% TEST_FILE=%,$(MAKEOVERRIDES))
ifneq ($(BAD_SETTINGS),)
$(error Unknown setting(s): $(BAD_SETTINGS). Use only ROWS, COLS, K, NUM_TESTS, SEED, MULT_LAT, TEST_FILE (uppercase))
endif

CXXFLAGS_RxC = $(CXXFLAGS) -DROWS=$(ROWS) -DCOLS=$(COLS) -DK=$(K) -DMULT_LAT=$(MULT_LAT)

default: help
	@echo ""
	@echo "ERROR: no target given. Plain 'make' does not build or run anything; use one of the commands above."
	@exit 1

help:
	@echo "Run these from the code/ folder, after 'source init.sh':"
	@echo "  make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3      run one test"
	@echo "  make systolic_array_nk ROWS=4 COLS=2 K=4 NUM_TESTS=100                    run one N < K test"
	@echo "  make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 TEST_FILE=test_axis.cpp   run one Part C test"
	@echo "  make submit                                                                create submission.zip"
	@echo "  make clean                                                                 remove build files and logs"
	@echo "Test scripts: ./run_inclass1.sh  ./run_inclass2.sh  ./run.sh  ./run_nk.sh  ./run_axis.sh test_axis.cpp 100"

check_tools:
	@command -v $(VERILATOR) >/dev/null 2>&1 || { echo "ERROR: verilator not found. Run 'source init.sh' in this terminal first (from the code/ folder)."; exit 1; }
	@$(PYTHON) -c 'import numpy' >/dev/null 2>&1 || { echo "ERROR: '$(PYTHON)' with numpy not found."; exit 1; }

systolic_array: check_tools
	@rm -rf obj_dir results.log
	@echo "-- PARAMETERS: ROWS=$(ROWS) COLS=$(COLS) K=$(K) NUM_TESTS=$(NUM_TESTS) SEED=$(SEED) MULT_LAT=$(MULT_LAT)"
	@echo "-- VERILATE ----------------"
	$(PYTHON) data_gen.py \
		--mode gen_data \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		--seed $(SEED)
	$(VERILATOR) $(VL_FLAGS_TEST_SYSTOLIC_ARRAY) $(VL_FLAGS) \
		-GROWS=$(ROWS) \
		-GCOLS=$(COLS) \
		-GMULT_LAT=$(MULT_LAT) \
		-GK=$(K) \
		test_systolic_array.cpp MAC.v ctrl.v adder.v multiplier.v synchronus_fifo.v -CFLAGS '$(CXXFLAGS_RxC)' 
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 32 -C obj_dir -f Vsystolic_array.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vsystolic_array
	$(PYTHON) data_gen.py \
		--mode verify \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		> results.log
	@echo "-- DONE --------------------"

systolic_array_nk: check_tools
	@rm -rf obj_dir results.log
	@echo "-- PARAMETERS: ROWS=$(ROWS) COLS=$(COLS) K=$(K) NUM_TESTS=$(NUM_TESTS) SEED=$(SEED) MULT_LAT=$(MULT_LAT)"
	@echo "-- VERILATE ----------------"
	$(PYTHON) data_gen.py \
		--mode gen_data \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		--seed $(SEED)
	$(VERILATOR) $(VL_FLAGS_TEST_SYSTOLIC_ARRAY) $(VL_FLAGS) \
		-GROWS=$(ROWS) \
		-GCOLS=$(COLS) \
		-GMULT_LAT=$(MULT_LAT) \
		-GK=$(K) \
		test_systolic_array.cpp MAC.v ctrl.v adder.v multiplier.v synchronus_fifo.v -CFLAGS '$(CXXFLAGS_RxC)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 32 -C obj_dir -f Vsystolic_array.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vsystolic_array
	$(PYTHON) data_gen_nk.py \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		> results.log
	@echo "-- DONE --------------------"

systolic_array_axis: check_tools
	@rm -rf obj_dir results.log
	@echo "-- PARAMETERS: ROWS=$(ROWS) COLS=$(COLS) K=$(K) NUM_TESTS=$(NUM_TESTS) SEED=$(SEED) MULT_LAT=$(MULT_LAT) TEST_FILE=$(TEST_FILE)"
	@echo "-- VERILATE ----------------"
	$(PYTHON) data_gen_axi.py \
		--mode gen_data \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		--seed $(SEED)
	$(VERILATOR) $(VL_FLAGS_TEST_SYSTOLIC_ARRAY_AXIS) $(VL_FLAGS) \
		-GROWS=$(ROWS) \
		-GCOLS=$(COLS) \
		-GMULT_LAT=$(MULT_LAT) \
		-GK=$(K) \
		$(TEST_FILE) systolic_array.v MAC.v ctrl.v adder.v multiplier.v synchronus_fifo.v -CFLAGS '$(CXXFLAGS_RxC)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 32 -C obj_dir -f Vsystolic_array_axis.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vsystolic_array_axis
	$(PYTHON) data_gen_axi.py \
		--mode verify \
		--a-size $(ROWS)x$(K) \
		--b-size $(K)x$(COLS) \
		--c-size $(ROWS)x$(COLS) \
		--num-tests $(NUM_TESTS) \
		> results.log
	@echo "-- DONE --------------------"

submit: 
	@echo "-- ZIPPING ALL THE FILE ---------"
	zip submission.zip ./*.v ./*.vh

maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir *.log *.dmp *.vpd *.bin core trace.vcd *.log
