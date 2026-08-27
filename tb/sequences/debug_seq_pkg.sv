`ifndef DEBUG_SEQ_PKG_SV
`define DEBUG_SEQ_PKG_SV

package debug_seq_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"
  `include "svt_jtag_defines.svi"
  `include "svt_jtypes.svi"
  `include "svt_swd_defines.svi"
  `include "svt_apb_defines.svi"
  `include "svt_axi_defines.svi"
  `include "svt_atb_defines.svi"

  `include "debug_reset_sequence.sv"
  `include "debug_entry_sequence.sv"

  `include "debug_apb_reg_sequence.sv"
  `include "debug_apb_reg_test_sequence.sv"
  `include "debug_apb_scenario_sequence.sv"
  `include "debug_apb_xfer_sequence.sv"

  `include "debug_atb_test_sequence.sv"
  `include "debug_dp_idcode_sequence.sv"
  `include "debug_dap_reg_access_sequence.sv"
`include "debug_dap_apb_access_sequence.sv"
`include "debug_swd_apb_access_sequence.sv"

endpackage

`endif
