`timescale 1ns/1ps

// ==========================================
// DEBUG PORT TOP MODULE
// ==========================================
// Standard UVM Verification Environment Structure
//
// Compilation Order (defined in filelist):
//   1. tb/ral/debug_sys_ral.sv        (Register model)
//   2. tb/sequences/debug_seq_pkg.sv  (All sequences)
//   3. tb/env/debug_env_pkg.sv        (Environment components)
//   4. tests/debug_test_pkg.sv        (Testcases only)
//   5. tb/debug_port_top.sv           (This file)
//
// Directory Structure:
//   tb/
//     ??? env/          (env_pkg, scoreboard, coverage, cfg, vseqr, env)
//     ??? sequences/    (seq_pkg, all layered sequences)
//     ??? ral/          (register model)
//     ??? interfaces/   (all SV interfaces)
//     ??? loopbacks/    (DUT loopback modules)
//     ??? debug_port_top.sv
//   tests/             (test_pkg + all testcases)
//   filelist/          (compile file lists)
//
// ==========================================

`ifndef DEBUG_PORT_JTAG
  `ifndef DEBUG_PORT_SWD
    `define DEBUG_PORT_JTAG
  `endif
`endif

// SVT VIP packages
`ifdef DEBUG_PORT_JTAG
  `include "svt_jtag.uvm.pkg"
`elsif DEBUG_PORT_SWD
  `include "svt_swd.uvm.pkg"
`endif
`include "svt_apb.uvm.pkg"
`include "svt_axi.uvm.pkg"
`include "svt_atb.pkg"

// Interfaces
`include "debug_reset_if.sv"

// Loopback DUT modules
`ifdef DEBUG_PORT_JTAG
  `include "debug_jtag_loopback.sv"
`elsif DEBUG_PORT_SWD
  `include "debug_swd_loopback.sv"
`endif
`include "debug_apb_loopback.sv"
`include "debug_atb_loopback.sv"

// RAL Model
`include "debug_sys_ral.sv"

// Sequence Package (Layer 1/2/3 sequences)
`include "debug_seq_pkg.sv"

// Environment Package (Scoreboard, Coverage, Env)
`include "debug_env_pkg.sv"

// Test Package (ONLY testcases - compiled LAST)
`include "debug_test_pkg.sv"

module debug_port_top;
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
  // Import our packages
  import debug_seq_pkg::*;
  import debug_env_pkg::*;
  import debug_test_pkg::*;

  // Clock and reset
  reg pclk = 0;
  reg preset_n = 1;
  always #5 pclk = ~pclk;

  initial begin
    #20 preset_n = 0;
    #50 preset_n = 1;
  end

  // Debug reset interface
  debug_reset_if reset_if(.clk(pclk));

  // Loopback connections (DUT)
`ifdef DEBUG_PORT_JTAG
  svt_jtag_if master_if();
  svt_jtag_if slave_if();
  debug_jtag_loopback jtag_loopback(.*);
`elsif DEBUG_PORT_SWD
  svt_swd_if master_if();
  svt_swd_if slave_if();
  debug_swd_loopback swd_loopback(.*);
`endif

  svt_apb_if #(
    .ADDR_WIDTH(16),
    .DATA_WIDTH(32)
  ) apb_master_if(pclk, preset_n);

  svt_apb_if #(
    .ADDR_WIDTH(16),
    .DATA_WIDTH(32)
  ) apb_slave_if(pclk, preset_n);

  svt_atb_if #(
    .ID_WIDTH(7),
    .DATA_WIDTH(32)
  ) atb_master_if(pclk, preset_n);

  svt_atb_if #(
    .ID_WIDTH(7),
    .DATA_WIDTH(32)
  ) atb_slave_if(pclk, preset_n);

  debug_apb_loopback apb_loopback(.*);
  debug_atb_loopback atb_loopback(.*);

  initial begin
    // ==========================================
    // CONFIG_DB INTERFACE ASSIGNMENTS
    // All interfaces retrieved via config_db.
    // NO hierarchical path references in UVM code.
    // ==========================================
    uvm_config_db#(virtual debug_reset_if.seq_mp)::set(
      null, "uvm_test_top.env.vseqr", "reset_vif", reset_if.seq_mp);

    uvm_config_db#(virtual svt_apb_if)::set(
      null, "uvm_test_top.env.apb_master_env.master", "vif", apb_master_if);
    uvm_config_db#(virtual svt_apb_if)::set(
      null, "uvm_test_top.env.apb_slave_env.slave[0]", "vif", apb_slave_if);

    uvm_config_db#(virtual svt_atb_if)::set(
      null, "uvm_test_top.env", "atb_vif", atb_master_if);

    run_test();
  end

  initial begin
    `ifdef VCS
      $fsdbDumpfile("sim_out/waves.fsdb");
      $fsdbDumpvars(0, debug_port_top);
    `endif
  end

endmodule