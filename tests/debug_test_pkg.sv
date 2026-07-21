`ifndef DEBUG_TEST_PKG_SV
`define DEBUG_TEST_PKG_SV

// ==========================================
// TEST PACKAGE - Only testcases live here
// ==========================================
// Compiled AFTER env_pkg and seq_pkg.
// Imports both env and sequences.
// NO environment components in this package.
// ==========================================

package debug_test_pkg;
  import uvm_pkg::*;
  import debug_seq_pkg::*;
  import debug_env_pkg::*;

  `include "uvm_macros.svh"

  // Base test class - all tests inherit from this
  `include "debug_port_base_test.sv"

  // Individual testcases
  `include "debug_port_smoke_test.sv"
  `include "debug_reg_access_test.sv"
  `include "debug_trace_test.sv"
  `include "debug_apb_xfer_test.sv"       // DEPRECATED
  `include "debug_apb_reg_test.sv"
  `include "debug_apb_scenario_test.sv"
  `include "debug_full_test.sv"

endpackage

`endif