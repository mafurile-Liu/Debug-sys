`ifndef DEBUG_JTAG_LOOPBACK_SV
`define DEBUG_JTAG_LOOPBACK_SV

module debug_jtag_loopback(
  svt_jtag_if      driver_if,
  svt_jtag_ctrl_if controller_if
);
  assign controller_if.tck = driver_if.tck;
  assign controller_if.tdi = driver_if.tdi;
  assign controller_if.tms = driver_if.tms;
  assign driver_if.tdo     = controller_if.tdo;
endmodule

`endif

