#------------------------------------------------------
# gt-cs3220: Makefile for building TinyRV test cases
#------------------------------------------------------

RISCV ?= /opt/risc-v-gnu/rv32im
RISCV_PREFIX ?= $(RISCV)/bin/riscv32-unknown-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -static -mcmodel=medlow -fvisibility=hidden -nostdlib -nostartfiles -T ./link.ld -I include/
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy --output-target=verilog --verilog-data-width=4
VMHTOMEM = python vmhtomem.py

# Revamp layout: previous-lab regression + public/hidden Lab 3 sets.
# (hidden/random and hidden/edge are produced by tools/gen_revamp_tests.py, but
#  their .S is also emitted so they can be rebuilt through this Makefile.)
SRCDIRS	= ./previous_tests/part1 ./previous_tests/part2 ./previous_tests/part3 \
	  ./public/inclass ./public/takehome ./student \
	  ./hidden/back_to_back ./hidden/edge ./hidden/random

SRCS 	= 	$(foreach dir, $(SRCDIRS), $(wildcard $(dir)/*.S))
ELF 	= 	$(SRCS:.S=.elf)
DUMP 	=	$(SRCS:.S=.dump)
MEM 	= 	$(SRCS:.S=.mem)

.PHONY: clean

default: all

all: $(MEM) $(DUMP)

%.mem: %.elf
	$(RISCV_OBJCOPY) $< $@
	$(VMHTOMEM) $@

%.dump: %.elf
	$(RISCV_OBJDUMP) $< > $@

%.elf: %.S
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $< -o $@

clean:
	$(RM) $(MEM) $(DUMP)