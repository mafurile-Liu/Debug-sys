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
//        |-- env/
//        |     |-- common/    (cfg, scoreboard, coverage, vseqr, ...)
//        |     |-- jtag/      (debug_port_env - JTAG+SWD)
//        |     |-- apb/       (debug_apb_env)
//        |     |-- atb/       (debug_atb_env)
//        |     |-- debug_env_pkg.sv
//        |     +-- debug_sys_env.sv (top env)
//        |-- sequences/    (seq_pkg, all layered sequences)
//        |-- ral/          (register model)
//        |-- interfaces/   (all SV interfaces)
//        |-- loopbacks/    (DUT loopback modules)
//        +-- debug_port_top.sv
//   tests/             (test_pkg + all testcases)
//   filelist/          (compile file lists)
//
// Protocol Selection (runtime plusarg):
//   +debug_port_proto=JTAG  (default)
//   +debug_port_proto=SWD
// ==========================================

// SVT VIP packages - JTAG and SWD are both compiled in
`include "svt_jtag.uvm.pkg"
`include "svt_swd.uvm.pkg"
`include "svt_apb.uvm.pkg"
`include "svt_axi.uvm.pkg"
`include "svt_atb.pkg"

// Interfaces
`include "debug_reset_if.sv"

// All loopback DUT modules
`include "debug_jtag_loopback.sv"
`include "debug_swd_loopback.sv"
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
  import svt_jtag_uvm_pkg::*;
  import svt_swd_uvm_pkg::*;
  import svt_apb_uvm_pkg::*;
  import svt_axi_uvm_pkg::*;
  import svt_atb_pkg::*;

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

  // ==========================================
  // JTAG interfaces + loopback
  // ==========================================
  svt_jtag_if jtag_driver_if();
  svt_jtag_if jtag_controller_if();
  debug_jtag_loopback jtag_loopback(
    .driver_if(jtag_driver_if),
    .controller_if(jtag_controller_if)
  );

  // ==========================================
  // SWD interfaces + loopback
  // ==========================================
  svt_swd_if swd_master_if();
  svt_swd_if swd_slave_if();
  debug_swd_loopback swd_loopback(
    .master_if(swd_master_if),
    .slave_if(swd_slave_if)
  );

  // ==========================================
  // APB interfaces + loopback
  // ==========================================
  svt_apb_if #(
    .ADDR_WIDTH(16),
    .DATA_WIDTH(32)
  ) apb_master_if(pclk, preset_n);

  svt_apb_if #(
    .ADDR_WIDTH(16),
    .DATA_WIDTH(32)
  ) apb_slave_if(pclk, preset_n);

  debug_apb_loopback apb_loopback(.*);

  // ==========================================
  // ATB interfaces + loopback
  // ==========================================
  svt_atb_if #(
    .ID_WIDTH(7),
    .DATA_WIDTH(32)
  ) atb_master_if(pclk, preset_n);

  svt_atb_if #(
    .ID_WIDTH(7),
    .DATA_WIDTH(32)
  ) atb_slave_if(pclk, preset_n);

  debug_atb_loopback atb_loopback(.*);

  initial begin
    // ==========================================
    // CONFIG_DB INTERFACE ASSIGNMENTS
    // All interfaces retrieved via config_db.
    // NO hierarchical path references in UVM code.
    //
    // UVM hierarchy:
    //   uvm_test_top.env
    //     |-- port_env
    //     |     |-- jtag_driver_agent
    //     |     |-- jtag_controller_agent
    //     |     |-- swd_master_agent
    //     |     +-- swd_slave_agent
    //     |-- apb_env
    //     |     |-- apb_master_env.master
    //     |     +-- apb_slave_env.slave[0]
    //     +-- atb_env.atb_env
    // ==========================================

    // Reset interface
    uvm_config_db#(virtual debug_reset_if.seq_mp)::set(
      null, "uvm_test_top.env.vseqr", "reset_vif", reset_if.seq_mp);

    // JTAG interfaces (to port_env.*)
    uvm_config_db#(virtual svt_jtag_if)::set(
      null, "uvm_test_top.env.port_env.jtag_driver_agent", "vif", jtag_driver_if);
    uvm_config_db#(virtual svt_jtag_if)::set(
      null, "uvm_test_top.env.port_env.jtag_controller_agent", "vif", jtag_controller_if);

    // SWD interfaces (to port_env.*)
    uvm_config_db#(virtual svt_swd_if)::set(
      null, "uvm_test_top.env.port_env.swd_master_agent", "vif", swd_master_if);
    uvm_config_db#(virtual svt_swd_if)::set(
      null, "uvm_test_top.env.port_env.swd_slave_agent", "vif", swd_slave_if);

    // APB interfaces (to apb_env.*)
    uvm_config_db#(virtual svt_apb_if)::set(
      null, "uvm_test_top.env.apb_env.apb_master_env.master", "vif", apb_master_if);
    uvm_config_db#(virtual svt_apb_if)::set(
      null, "uvm_test_top.env.apb_env.apb_slave_env.slave[0]", "vif", apb_slave_if);

    // ATB interface (to atb_env)
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
