`ifndef DEBUG_APB_LOOPBACK_SV
`define DEBUG_APB_LOOPBACK_SV

module debug_apb_loopback(
  svt_apb_if master_if,
  svt_apb_if slave_if
);
  assign slave_if.psel    = master_if.psel;
  assign slave_if.penable = master_if.penable;
  assign slave_if.pwrite  = master_if.pwrite;
  assign slave_if.paddr   = master_if.paddr;
  assign slave_if.pwdata  = master_if.pwdata;
  assign slave_if.pstrb   = master_if.pstrb;
  assign slave_if.pprot   = master_if.pprot;

  assign master_if.slave_if[0].prdata  = slave_if.slave_if[0].prdata;
  assign master_if.slave_if[0].pready  = slave_if.slave_if[0].pready;
  assign master_if.slave_if[0].pslverr = slave_if.slave_if[0].pslverr;
endmodule

`endif

