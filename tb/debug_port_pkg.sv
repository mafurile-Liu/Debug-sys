`ifndef DEBUG_PORT_PKG_SV
`define DEBUG_PORT_PKG_SV

package debug_port_pkg;
  import uvm_pkg::*;
  import svt_uvm_pkg::*;
  import svt_apb_uvm_pkg::*;
  import svt_axi_uvm_pkg::*;
  import svt_atb_pkg::*;
`ifdef DEBUG_PORT_JTAG
  import svt_jtag_uvm_pkg::*;
`elsif DEBUG_PORT_SWD
  import svt_swd_uvm_pkg::*;
`endif

  `include "uvm_macros.svh"
  `include "debug_sys_analysis_decls.svh"
  `include "debug_sys_addr_map.sv"
  `include "debug_sys_cfg.sv"
  `include "debug_sys_ral.sv"
  `include "debug_sys_predictor.sv"
  `include "debug_sys_scoreboard.sv"
  `include "debug_sys_virtual_sequencer.sv"
  `include "debug_sys_env.sv"
  `include "debug_reset_sequence.sv"
  `include "debug_entry_sequence.sv"
  `include "debug_apb_xfer_sequence.sv"
  `include "debug_port_base_test.sv"
  `include "debug_port_smoke_test.sv"
  `include "debug_entry_test.sv"
  `include "debug_reg_access_test.sv"
  `include "debug_trace_test.sv"
  `include "debug_full_test.sv"
  `include "debug_apb_xfer_test.sv"
endpackage

`endif
