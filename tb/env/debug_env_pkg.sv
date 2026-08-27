`ifndef DEBUG_ENV_PKG_SV
`define DEBUG_ENV_PKG_SV

package debug_env_pkg;
  import uvm_pkg::*;
  import debug_seq_pkg::*;

  `include "uvm_macros.svh"

  // ==========================================
  // 编译顺序: 自底向上
  // 注意: RAL 模型在 tb/ral/ 下, 由 filelist 提前编译
  // ==========================================

  // Step 1: 公共组件 (配置、地址映射、类型声明)
  `include "common/debug_sys_analysis_decls.svh"
  `include "common/debug_sys_cfg.sv"
  `include "common/debug_sys_addr_map.sv"

  // Step 2: 公共组件 (scoreboard, coverage, predictor, vseqr)
  `include "common/debug_sys_scoreboard.sv"
  `include "common/debug_sys_coverage.sv"
  `include "common/debug_sys_predictor.sv"
  `include "common/debug_sys_virtual_sequencer.sv"

  // Step 3: 各协议子 env
  `include "jtag/debug_port_env.sv"
  `include "apb/debug_apb_env.sv"
  `include "atb/debug_atb_env.sv"

  // Step 4: 顶层 env
  `include "debug_sys_env.sv"

endpackage

`endif
