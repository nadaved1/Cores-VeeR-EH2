# SPDX-License-Identifier: Apache-2.0
# Copyright 2020 Western Digital Corporation or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# need to be removed for opensource
CONF_PARAMS = -set=build_axi4

TEST_CFLAGS = -g -O3 -funroll-all-loops 

ABI = -mabi=ilp32 -march=rv32imac_zicsr



# Check for RV_ROOT
ifeq (,$(wildcard ${RV_ROOT}/configs/veer.config))
$(error env var RV_ROOT does not point to a valid dir! Exiting!)
endif

# Allow snapshot override
target = default
snapshot = $(target)

# Allow tool override
VEER_CONFIG = ${RV_ROOT}/configs/veer.config
IRUN = xrun
VCS = vcs
VLOG = qverilog
VERILATOR = verilator
# Warnings to suppress for the Verilator build. -Wno-STMTDLY is required for
# Verilator >= 5.x, which promotes the #delay in SimJTAG.v to a fatal error.
VERILATOR_WARN = -Wno-WIDTH -Wno-UNOPTFLAT -Wno-IMPLICIT -Wno-STMTDLY
RIVIERA = riviera
GCC_PREFIX = riscv-none-elf
BUILD_DIR = snapshots/${snapshot}
TBDIR = ${RV_ROOT}/testbench

# UVM bus/SoC integration environment (commercial simulators only). These are
# additive: they use verif/uvm/uvm.flist + tb_uvm_top and never touch the
# Verilator flow (testbench/flist + tb_top). UVM is supplied by the simulator.
UVM_DIR  = ${RV_ROOT}/verif/uvm
UVM_TEST = veer_bus_smoke_test
UVM_VERB = UVM_MEDIUM
# Extra defines for the UVM build, e.g. UVM_DEFINES=+define+DMA_UVM_MASTER to let
# the UVM DMA master own the DMA port (required by the dma/stress tests).
UVM_DEFINES =
# Vendor UVM library tags; override if your install differs.
VCS_UVM_OPTS  = -ntb_opts uvm-1.2
XRUN_UVM_OPTS = -uvm -uvmhome CDNS-1.2



# Define default test name
TEST = hello_world

# Define default test directories
TEST_DIR = ${TBDIR}/asm
HEX_DIR = ${TBDIR}/hex

OFILES = $(TEST).o

ifneq (,$(wildcard $(TBDIR)/tests/$(TEST)))
  TEST_DIR = $(TBDIR)/tests/$(TEST)
endif

ifdef debug
 DEBUG_PLUS = +dumpon
 IRUN_DEBUG = -access +rc
 IRUN_DEBUG_RUN = -input ${RV_ROOT}/testbench/input.tcl
 VCS_DEBUG = -debug_access
 VERILATOR_DEBUG = --trace
 # Name the Verilator VCD after the test so each run dumps <TEST>.vcd
 # (e.g. dhry.vcd) into the working dir instead of a generic sim.vcd.
 VERILATOR_RUN_ARGS = +vcdfile=$(TEST).vcd
 RIVIERA_DEBUG = +access +r
endif

# provide specific link file
ifeq (,$(wildcard $(TEST_DIR)/$(TEST).ld))
	LINK = $(TBDIR)/link.ld
else
	LINK = $(TEST_DIR)/$(TEST).ld
endif

VPATH = $(TEST_DIR) $(BUILD_DIR) $(TBDIR)

-include $(TEST_DIR)/$(TEST).mki


TBFILES = $(TBDIR)/tb_top.sv $(TBDIR)/ahb_sif.sv

defines  = $(BUILD_DIR)/common_defines.vh
defines += ${RV_ROOT}/design/include/eh2_def.sv
defines += $(BUILD_DIR)/eh2_pdef.vh
includes = -I${BUILD_DIR}

# CFLAGS for verilator generated Makefiles. Without -std=c++11 it
# complains for `auto` variables
CFLAGS += "-std=c++11"

# Optimization for better performance; alternative is nothing for
# slower runtime (faster compiles) -O2 for faster runtime (slower
# compiles), or -O for balance.
VERILATOR_MAKE_FLAGS = OPT_FAST="-Os"

# Targets
all: clean verilator

clean:
	rm -rf *.log *.s *.hex *.dis *.tbl irun* vcs* simv* snapshots veer* \
	verilator* *.map *.exe obj* *.o ucli.key vc_hdrs.h csrc *.csv \
	work dataset.asdb  library.cfg vsimsa.cfg  riviera-build wave.asdb \
	SimJTAG.so .program_hex_test \
	run/* \
	work_uvm xcelium.d xrun.history xrun.key *-uvm-build cov_work urgReport compile_time.txt



################## Model Builds ###############################

# If define files do not exist, then run veer.config.
${BUILD_DIR}/defines.h:
	BUILD_PATH=${BUILD_DIR} ${RV_ROOT}/configs/veer.config -target=$(target) $(CONF_PARAMS)

verilator-build: ${TBFILES} ${BUILD_DIR}/defines.h test_tb_top.cpp
	echo '`undef RV_ASSERT_ON' >> ${BUILD_DIR}/common_defines.vh
	$(VERILATOR)  --cc -CFLAGS ${CFLAGS} $(defines) \
	  $(includes) -I${RV_ROOT}/testbench -f ${RV_ROOT}/testbench/flist \
	  $(VERILATOR_WARN) ${TBFILES} --top-module tb_top \
	  -exe test_tb_top.cpp --autoflush $(VERILATOR_DEBUG) --no-timing
	$(MAKE) -j -C obj_dir -f Vtb_top.mk $(VERILATOR_MAKE_FLAGS)
	touch verilator-build

vcs-build: ${TBFILES} ${BUILD_DIR}/defines.h
	$(VCS) -full64 -assert svaext -sverilog \
	  +error+500  $(defines) +incdir+$(BUILD_DIR)\
	  -f ${RV_ROOT}/testbench/flist ${TBFILES} -l vcs.log
	touch vcs-build

irun-build: ${TBFILES} ${BUILD_DIR}/defines.h
	$(IRUN) -64bit -elaborate $(IRUN_DEBUG) -q -sv -sysv  -nowarn CUVIHR \
	  -xmlibdirpath $(BUILD_DIR) -xmlibdirname veer.build \
	  -vlog_ext +.vh+.h $(defines) +incdir+$(BUILD_DIR) \
	  -f ${RV_ROOT}/testbench/flist -top tb_top  ${TBFILES} \
	  -elaborate  -snapshot ${snapshot} $(profile)
	touch irun-build

SimJTAG.so : ${RV_ROOT}/testbench/remote_bitbang.cc ${RV_ROOT}/testbench/SimJTAG.cc
	ccomp -dpi ${RV_ROOT}/testbench/remote_bitbang.cc ${RV_ROOT}/testbench/SimJTAG.cc -o SimJTAG

riviera-build: ${TBFILES} ${BUILD_DIR}/defines.h ${RV_ROOT}/testbench/flist.riviera
	vlib work
	vlog -work work \
		+incdir+${BUILD_DIR} \
		-y ${RV_ROOT}/design/lib +libext+.v+.vh \
		$(defines) \
		-f ${RV_ROOT}/testbench/flist.riviera \
		${TBFILES}
	touch riviera-build

################## UVM bus/SoC integration Builds #############################

# VCS: compile the UVM env + tb_uvm_top into ./simv_uvm (separate from ./simv so
# the directed vcs flow and the UVM flow can coexist).
vcs-uvm-build: ${BUILD_DIR}/defines.h
	@t0=$$(date +%s); \
	$(VCS) -full64 -assert svaext -sverilog $(VCS_UVM_OPTS) -timescale=1ns/1ps \
	  +define+UVM $(UVM_DEFINES) +error+500 $(defines) +incdir+$(BUILD_DIR) \
	  -f ${UVM_DIR}/uvm.flist -top tb_uvm_top -o simv_uvm -l vcs_uvm.log; \
	rc=$$?; t1=$$(date +%s); echo $$((t1 - t0)) > compile_time.txt; \
	echo "=== VCS compile wallclock: $$((t1 - t0)) s (saved to compile_time.txt) ==="; \
	exit $$rc
	touch vcs-uvm-build

#################### UVM Simulation Run ###############################

# VCS UVM run. Example:
#   make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_smoke_test
vcs-uvm: program.hex vcs-uvm-build
	./simv_uvm +UVM_TESTNAME=$(UVM_TEST) +UVM_VERBOSITY=$(UVM_VERB) \
	  $(DEBUG_PLUS) +vcs+lic+wait -l sim_uvm.log $(run_arg) +UVM_NO_RELNOTES -suppress=ASLR_DETECTED_INFO

# Xcelium UVM run (single-step elaborate + run; compile time is not separable
# here, so clear compile_time.txt and the report shows it as n/a).
xrun-uvm: program.hex ${BUILD_DIR}/defines.h
	rm -f compile_time.txt
	$(IRUN) -64bit +lic_queue -licqueue -q -sv -sysv $(XRUN_UVM_OPTS) -timescale 1ns/1ps \
	  -nowarn CUVIHR +define+UVM $(UVM_DEFINES) -vlog_ext +.vh+.h $(defines) +incdir+$(BUILD_DIR) \
	  -f ${UVM_DIR}/uvm.flist -top tb_uvm_top \
	  +UVM_TESTNAME=$(UVM_TEST) +UVM_VERBOSITY=$(UVM_VERB) $(run_arg) -l xrun_uvm.log

# Questa UVM run. Assumes a Questa install with bundled UVM (-mfcu).
questa-uvm: program.hex ${BUILD_DIR}/defines.h
	vlib work_uvm
	@t0=$$(date +%s); \
	vlog -work work_uvm -sv -mfcu -timescale=1ns/1ps +define+UVM $(UVM_DEFINES) +incdir+${BUILD_DIR} \
	  $(defines) -f ${UVM_DIR}/uvm.flist -l vlog_uvm.log; \
	rc=$$?; t1=$$(date +%s); echo $$((t1 - t0)) > compile_time.txt; \
	echo "=== Questa compile wallclock: $$((t1 - t0)) s ==="; \
	exit $$rc
	vsim -c -lib work_uvm tb_uvm_top +UVM_TESTNAME=$(UVM_TEST) \
	  +UVM_VERBOSITY=$(UVM_VERB) -do "run -all; quit" -l questa_uvm.log

#################### TEST Simulation Run ###############################

verilator: program.hex verilator-build
	./obj_dir/Vtb_top $(run_arg) $(VERILATOR_RUN_ARGS)

irun: program.hex irun-build
	$(IRUN) -64bit  +lic_queue -licqueue \
	  -status -xmlibdirpath $(BUILD_DIR) -xmlibdirname veer.build \
	  -snapshot ${snapshot} -r $(snapshot) $(IRUN_DEBUG_RUN) $(run_arg) $(profile)

vcs: program.hex vcs-build
	./simv $(DEBUG_PLUS) +vcs+lic+wait  -l vcs.log $(run_arg)

vlog: program.hex ${TBFILES} ${BUILD_DIR}/defines.h
	$(VLOG) -l vlog.log -sv -mfcu +incdir+${BUILD_DIR}\
        $(defines) -f ${RV_ROOT}/testbench/flist ${TBFILES} -R +nowarn3829 ${DEBUG_PLUS} $(run_arg)

riviera: program.hex riviera-build SimJTAG.so
	vsim -c -lib work ${DEBUG_PLUS} ${RIVIERA_DEBUG} tb_top -sv_lib SimJTAG -do "run -all; exit" -l riviera.log



#################### TEST Build #######################################

ifeq ($(shell which $(GCC_PREFIX)-gcc 2> /dev/null),)
# Canned hex files all share one mtime, so a normal prerequisite won't force a
# re-copy when TEST changes. Use FORCE + a stamp of the last TEST so program.hex
# is refreshed whenever the selected test differs from what was last copied.
program.hex: ${BUILD_DIR}/defines.h FORCE
	@if [ "$$(cat .program_hex_test 2> /dev/null)" != "$(TEST)" ] || [ ! -f program.hex ]; then \
	  echo " !!! No $(GCC_PREFIX)-gcc in path, using canned hex files !!"; \
	  cp ${HEX_DIR}/$(TEST).hex program.hex; \
	  echo "$(TEST)" > .program_hex_test; \
	fi
else
ifneq (,$(wildcard $(TEST_DIR)/$(TEST).makefile))
program.hex:
	@echo Building $(TEST) via $(TEST_DIR)/$(TEST).makefile
	$(MAKE) -f $(TEST_DIR)/$(TEST).makefile
else
program.hex: $(OFILES) $(LINK)
	@echo Building $(TEST)
	$(GCC_PREFIX)-gcc $(ABI) -nostartfiles -lgcc -T$(LINK) -Wl,-Map=$(TEST).map -o $(TEST).exe $(OFILES)
	$(GCC_PREFIX)-objcopy -O verilog  $(TEST).exe program.hex
	$(GCC_PREFIX)-objdump -S  $(TEST).exe > $(TEST).dis
	@echo Completed building $(TEST)


%.o : %.s ${BUILD_DIR}/defines.h
	$(GCC_PREFIX)-cpp -I${BUILD_DIR}  $<  > $*.cpp.s
	$(GCC_PREFIX)-as ${ABI} $*.cpp.s -o $@


%.o : %.c ${BUILD_DIR}/defines.h
	$(GCC_PREFIX)-gcc ${includes} ${TEST_CFLAGS} -DCOMPILER_FLAGS="\"${TEST_CFLAGS}\"" ${ABI} -std=gnu17 -c $< -o $@

endif
endif


help:
	@echo Make sure the environment variable RV_ROOT is set.
	@echo Possible targets: verilator vcs irun vlog riviera help clean all verilator-build irun-build vcs-build riviera-build program.hex
	@echo UVM bus/SoC integration targets: vcs-uvm vcs-uvm-build xrun-uvm questa-uvm "(set UVM_TEST=<test>)"

FORCE: ;
.PHONY: help clean verilator vcs irun vlog riviera vcs-uvm xrun-uvm questa-uvm FORCE
