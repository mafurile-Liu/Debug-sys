`ifndef DEBUG_SWD_LOOPBACK_SV
`define DEBUG_SWD_LOOPBACK_SV

module debug_swd_loopback(
  svt_swd_if master_if,
  svt_swd_if slave_if
);
  assign slave_if.swd_clk = master_if.swd_clk;
  tran swdio_link(master_if.swd_data, slave_if.swd_data);
endmodule

`endif

