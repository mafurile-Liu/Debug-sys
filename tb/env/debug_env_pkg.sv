`ifndef DEBUG_ENV_PKG_SV
`define DEBUG_ENV_PKG_SV

// ==========================================
// ENVIRONMENT PACKAGE
// ==========================================
package debug_env_pkg;
  import uvm_pkg::*;
  import debug_seq_pkg::*;

  `include "uvm_macros.svh"
  `include "svt_jtag_defines.svi"
  `include "svt_jtypes.svi"
  `include "svt_swd_defines.svi"
  `include "svt_apb_defines.svi"
  `include "svt_axi_defines.svi"
  `include "svt_atb_defines.svi"

  // Project-specific VIP configurations (from tb/configs)
  `include "cust_apb_cfg.sv"
  `include "cust_jtag_cfg.sv"
  `include "cust_swd_cfg.sv"
  `include "cust_axi_cfg.sv"
  `include "cust_atb_cfg.sv"

  `include "debug_sys_cfg.sv"
  `include "debug_sys_scoreboard.sv"
  `include "debug_sys_coverage.sv"
  `include "debug_sys_virtual_sequencer.sv"
  `include "debug_sys_env.sv"

endpackage

`endif