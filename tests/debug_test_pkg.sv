`ifndef DEBUG_TEST_PKG_SV
`define DEBUG_TEST_PKG_SV

package debug_test_pkg;
  import uvm_pkg::*;
  import debug_seq_pkg::*;
  import debug_env_pkg::*;

  `include "uvm_macros.svh"

  `include "debug_port_base_test.sv"
  `include "debug_port_smoke_test.sv"
  `include "debug_reg_access_test.sv"
  `include "debug_trace_test.sv"
  `include "debug_apb_xfer_test.sv"
  `include "debug_apb_reg_test.sv"
  `include "debug_apb_scenario_test.sv"
  `include "debug_atb_loopback_test.sv"
  `include "debug_dp_idcode_test.sv"
  `include "debug_dap_reg_access_test.sv"
`include "debug_dap_apb_access_test.sv"
`include "debug_swd_apb_access_test.sv"
  `include "debug_full_test.sv"

endpackage

`endif
