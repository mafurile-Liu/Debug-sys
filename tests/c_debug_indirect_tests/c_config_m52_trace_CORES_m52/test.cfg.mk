# test.cfg.mk - ap0_romt_grp_scan
UVM_TESTNAME_PLUS := +UVM_TESTNAME=aon_normal_test
CORES := M52
M52_DDR_MODE := 1
#M52_SRAM_MODE := 1

# include ${TOT_DIR}/verif/it/aon/tb/default.cfg.mk