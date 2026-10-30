`ifndef DEBUG_ENV_PKG_SV
`define DEBUG_ENV_PKG_SV

package debug_env_pkg;
  import uvm_pkg::*;
  import debug_seq_pkg::*;
  import ect_aon_pkg::*;

  `include "uvm_macros.svh"

  // ==========================================
  // ????: ????
  // ??: RAL ??? tb/ral/ ?, ? filelist ????
  // ==========================================

  // Step 1: ???? (????????????)
  `include "common/debug_sys_analysis_decls.svh"
  `include "common/debug_sys_cfg.sv"
  `include "common/debug_sys_addr_map.sv"

  // Step 2: ???? (scoreboard, coverage, predictor, vseqr)
  `include "common/debug_sys_scoreboard.sv"
  `include "common/debug_sys_coverage.sv"
  `include "common/debug_sys_predictor.sv"
  `include "common/debug_sys_virtual_sequencer.sv"

  // Step 3: ???? env
  `include "jtag/debug_port_env.sv"
  `include "apb/debug_apb_env.sv"
  `include "atb/debug_atb_env.sv"

  // Step 4: ?? env
  `include "debug_sys_env.sv"

endpackage

`endif
