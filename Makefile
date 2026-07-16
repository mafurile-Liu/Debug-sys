PORT ?= jtag
TEST ?= debug_full_test
WAVES ?= 0

DESIGNWARE_HOME ?=
SVT_COMMON ?= $(DESIGNWARE_HOME)/vip/svt/common/latest
JTAG_VIP ?= $(DESIGNWARE_HOME)/vip/svt/jtag_svt/latest
SWD_VIP ?= $(DESIGNWARE_HOME)/vip/svt/swd_svt/latest
AMBA_VIP ?= $(DESIGNWARE_HOME)/vip/svt/amba_svt/latest

VCS ?= vcs

ifeq ($(PORT),jtag)
  PORT_DEFINE := +define+DEBUG_PORT_JTAG +define+SVT_JTAG
  PORT_ROOT := $(JTAG_VIP)
else ifeq ($(PORT),swd)
  PORT_DEFINE := +define+DEBUG_PORT_SWD +define+SVT_SWD
  PORT_ROOT := $(SWD_VIP)
else
  $(error PORT must be jtag or swd)
endif

COMMON_INCDIRS := \
  +incdir+$(SVT_COMMON)/sverilog/include \
  +incdir+$(SVT_COMMON)/sverilog/src/vcs

PORT_INCDIRS := \
  +incdir+$(PORT_ROOT)/sverilog/include \
  $(foreach d,$(wildcard $(PORT_ROOT)/*/sverilog/include),+incdir+$(d)) \
  $(foreach d,$(wildcard $(PORT_ROOT)/*/sverilog/src/vcs),+incdir+$(d))

AMBA_INCDIRS := \
  +incdir+$(AMBA_VIP)/sverilog/include \
  +incdir+$(AMBA_VIP)/sverilog/src/vcs \
  $(foreach d,$(wildcard $(AMBA_VIP)/*/sverilog/include),+incdir+$(d)) \
  $(foreach d,$(wildcard $(AMBA_VIP)/*/sverilog/src/vcs),+incdir+$(d))

TB_INCDIRS := +incdir+../../tb +incdir+../../tb/env +incdir+../../tb/tests
WAVE_DEFINE := $(if $(filter 1,$(WAVES)),+define+WAVES_VCD,)

.PHONY: all check-env check lint build run clean

all: build

check-env:
	@test -n "$(DESIGNWARE_HOME)" || { echo "ERROR: set DESIGNWARE_HOME"; exit 2; }
	@test -d "$(SVT_COMMON)" || { echo "ERROR: SVT_COMMON not found: $(SVT_COMMON)"; exit 2; }
	@test -d "$(PORT_ROOT)" || { echo "ERROR: VIP root not found: $(PORT_ROOT)"; exit 2; }
	@test -d "$(AMBA_VIP)" || { echo "ERROR: AMBA VIP root not found: $(AMBA_VIP)"; exit 2; }
	@command -v $(VCS) >/dev/null || { echo "ERROR: VCS not found"; exit 2; }

check:
	python3 scripts/check_project.py

lint: check
	python3 scripts/lint_sv.py

build: check-env check
	mkdir -p build/$(PORT)
	cd build/$(PORT) && $(VCS) -full64 -sverilog -ntb_opts uvm-1.2 \
	  -timescale=1ns/1ps +define+SVT_UVM_TECHNOLOGY=1 \
	  $(PORT_DEFINE) $(WAVE_DEFINE) \
	  $(COMMON_INCDIRS) $(PORT_INCDIRS) $(AMBA_INCDIRS) \
	  $(TB_INCDIRS) \
	  ../../tb/debug_port_top.sv -top debug_port_top -o simv \
	  -l compile.log

run: build
	cd build/$(PORT) && ./simv +UVM_TESTNAME=$(TEST) -l run.log

clean:
	rm -rf build
