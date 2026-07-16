`timescale 1ns/1ps

`ifndef DEBUG_PORT_JTAG
  `ifndef DEBUG_PORT_SWD
    `define DEBUG_PORT_JTAG
  `endif
`endif

`ifdef DEBUG_PORT_JTAG
  `include "svt_jtag.uvm.pkg"
`elsif DEBUG_PORT_SWD
  `include "svt_swd.uvm.pkg"
`endif
`include "svt_apb.uvm.pkg"
`include "svt_axi.uvm.pkg"
`include "svt_atb.pkg"

`include "debug_reset_if.sv"
`ifdef DEBUG_PORT_JTAG
  `include "debug_jtag_loopback.sv"
`elsif DEBUG_PORT_SWD
  `include "debug_swd_loopback.sv"
`endif
`include "debug_apb_loopback.sv"
`include "debug_atb_loopback.sv"
`include "debug_port_pkg.sv"

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
  import debug_port_pkg::*;

  localparam time REF_CLK_PERIOD = 10ns;
  bit ref_clk = 1'b0;
  always #(REF_CLK_PERIOD/2) ref_clk = ~ref_clk;

  debug_reset_if reset_if(ref_clk);

`ifdef DEBUG_PORT_JTAG
  svt_jtag_if driver_if();
  svt_jtag_ctrl_if controller_if();

  assign driver_if.trst = reset_if.reset_n;
  assign controller_if.trst = reset_if.reset_n;

  debug_jtag_loopback loopback(driver_if, controller_if);
`elsif DEBUG_PORT_SWD
  svt_swd_if master_if();
  svt_swd_if slave_if();

  assign master_if.reset = reset_if.reset_n;
  assign slave_if.reset = reset_if.reset_n;

  debug_swd_loopback loopback(master_if, slave_if);
`endif

  svt_apb_if apb_master_if();
  svt_apb_if apb_slave_if();
  assign apb_master_if.pclk = ref_clk;
  assign apb_slave_if.pclk = ref_clk;
  assign apb_master_if.presetn = reset_if.reset_n;
  assign apb_slave_if.presetn = reset_if.reset_n;
  debug_apb_loopback apb_loopback(apb_master_if, apb_slave_if);

  svt_axi_if axi_monitor_if();
  assign axi_monitor_if.common_aclk = ref_clk;
  assign axi_monitor_if.master_if[0].aresetn = reset_if.reset_n;
  assign axi_monitor_if.slave_if[0].aresetn = reset_if.reset_n;

  svt_atb_if atb_if();
  assign atb_if.common_atclk = ref_clk;
  assign atb_if.master_if[0].atresetn = reset_if.reset_n;
  assign atb_if.slave_if[0].atresetn = reset_if.reset_n;
  assign atb_if.master_if[0].atclken = 1'b1;
  assign atb_if.slave_if[0].atclken = 1'b1;
  debug_atb_loopback atb_loopback(atb_if);

  initial begin
`ifdef DEBUG_PORT_JTAG
    uvm_config_db#(virtual svt_jtag_if)::set(
      null, "uvm_test_top.env.driver_agent*", "vif", driver_if);
    uvm_config_db#(virtual svt_jtag_ctrl_if)::set(
      null, "uvm_test_top.env.controller_agent*", "ctrl_vif", controller_if);
`elsif DEBUG_PORT_SWD
    uvm_config_db#(virtual svt_swd_if)::set(
      null, "uvm_test_top.env.master_agent*", "vif", master_if);
    uvm_config_db#(virtual svt_swd_if)::set(
      null, "uvm_test_top.env.slave_agent*", "vif", slave_if);
`endif
    uvm_config_db#(svt_apb_vif)::set(
      null, "uvm_test_top.env.apb_master_env", "vif", apb_master_if);
    uvm_config_db#(svt_apb_vif)::set(
      null, "uvm_test_top.env.apb_slave_env", "vif", apb_slave_if);
    uvm_config_db#(svt_axi_vif)::set(
      null, "uvm_test_top.env.axi_monitor_env", "vif", axi_monitor_if);
    uvm_config_db#(virtual svt_atb_if)::set(
      null, "uvm_test_top.env", "atb_vif", atb_if);
    uvm_config_db#(virtual debug_reset_if.seq_mp)::set(
      null, "uvm_test_top.env.vseqr", "reset_vif", reset_if.seq_mp);

    run_test();
  end

`ifdef WAVES_VCD
  initial begin
    $dumpfile("debug_port.vcd");
    $dumpvars(0, debug_port_top);
  end
`endif
endmodule
