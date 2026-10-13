
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

.PHONY: default tests submit clean waveform

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

ifdef IDMEMINITFILE
	CXXFLAGS += -DIDMEMINITFILE=$(IDMEMINITFILE)
endif

VX_DEFINE = $(PWD)/define.vh
SED_STRING = 's|define IDMEMINITFILE.*|define IDMEMINITFILE "$(IDMEMINITFILE)"|g' 
VL_FLAGS += --exe -cc pipeline.v --top-module pipeline --trace --trace-structs
#VL_FLAGS += --assert -Wall -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
VL_FLAGS += --assert -Wpedantic -Wno-DECLFILENAME -Wno-UNUSED --x-initial unique --x-assign unique
CXXFLAGS += -DVCD_OUTPUT -DDPRINTF
#CXXFLAGS += -DVCD_OUTPUT 
LDFLAGS += 

default:
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VL_FLAGS) sim_main.cpp fe_stage.v de_stage.v mem_stage.v wb_stage.v agex_stage.v divider.v external_alu_wrapper.v FU_stage.v multiplier.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vpipeline.mk 
	@echo "-- RUN ---------------------"
	obj_dir/Vpipeline
	@echo "-- DONE --------------------"
	
tests:
	@echo "-- VERILATE ----------------"
	@echo $(IDMEMINITFILE)
	@echo $(VX_DEFINE)
	sed -i $(SED_STRING) $(VX_DEFINE)
	$(VERILATOR) $(VL_FLAGS) sim_main.cpp fe_stage.v de_stage.v mem_stage.v wb_stage.v agex_stage.v divider.v external_alu_wrapper.v FU_stage.v multiplier.v -CFLAGS '$(CXXFLAGS)'
	@echo "-- COMPILE -----------------"
	$(MAKE) -j 4 -C obj_dir -f Vpipeline.mk
	@echo "-- RUN ---------------------"
	obj_dir/Vpipeline
	@echo "-- DONE --------------------"

submit:
	@echo "-- ZIPPING SUBMISSION ---------"
	@rm -f submission.zip
	@# Core RTL package (enough for the in-class Gradescope autograder).
	zip submission.zip ./*.v ./*.vh ./sim_main.cpp ./Makefile
	@# Take-home extras: include when present; skip quietly for in-class-only submits.
	@if [ -f test/tools/gen_revamp_tests.py ]; then zip submission.zip test/tools/gen_revamp_tests.py; \
	else echo "NOTE: no test/tools/gen_revamp_tests.py — omit for now; needed for take-home."; fi
	@if [ -f test/student/random_stress.mem ]; then zip submission.zip test/student/random_stress.mem; \
	else echo "NOTE: no test/student/random_stress.mem — fine for in-class; for take-home run: python3 test/tools/gen_revamp_tests.py --seed <your_seed>"; fi
	@if [ -f test/student/random_stress.lst ]; then zip submission.zip test/student/random_stress.lst; fi
	@# Optional write-up PDF if present at lab root (else upload PDF separately on Gradescope).
	@if [ -f writeup.pdf ]; then zip submission.zip writeup.pdf; \
	elif ls *.pdf >/dev/null 2>&1; then zip submission.zip *.pdf; \
	else echo "NOTE: no writeup.pdf (or *.pdf) in lab root — upload the write-up PDF on Gradescope if required."; fi
	@echo "-- submission.zip contents ---------"
	@unzip -l submission.zip
	@echo "-- DONE: upload submission.zip to Gradescope ---------"

# Regenerate the in-class handshake reference VCD for GTKWave.
WAVEFORM_TEST ?= test/public/inclass/handshake_div.mem
WAVEFORM_DIR  ?= artifacts/waveform
WAVEFORM_VCD  ?= $(WAVEFORM_DIR)/lab3_inclass_handshake.vcd

waveform:
	@echo "-- WAVEFORM: handshake reference ----------------"
	@test -f $(WAVEFORM_TEST) || (echo "missing $(WAVEFORM_TEST); this file should already be in your skeleton checkout" && exit 1)
	@mkdir -p $(WAVEFORM_DIR)
	@echo $(WAVEFORM_TEST)
	sed -i 's|define IDMEMINITFILE.*|define IDMEMINITFILE "$(WAVEFORM_TEST)"|g' $(VX_DEFINE)
	$(VERILATOR) $(VL_FLAGS) sim_main.cpp fe_stage.v de_stage.v mem_stage.v wb_stage.v agex_stage.v divider.v external_alu_wrapper.v FU_stage.v multiplier.v -CFLAGS '$(CXXFLAGS)'
	$(MAKE) -j 4 -C obj_dir -f Vpipeline.mk
	IDMEMINITFILE=$(WAVEFORM_TEST) obj_dir/Vpipeline
	cp trace.vcd $(WAVEFORM_VCD)
	@echo "Wrote $(WAVEFORM_VCD)"
	@echo "Open in GTKWave: gtkwave $(WAVEFORM_VCD) $(WAVEFORM_DIR)/lab3_inclass_handshake.gtkw"

maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir *.log *.dmp *.vpd core trace.vcd
