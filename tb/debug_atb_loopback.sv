`ifndef DEBUG_ATB_LOOPBACK_SV
`define DEBUG_ATB_LOOPBACK_SV

module debug_atb_loopback(svt_atb_if atb_if);
  assign atb_if.slave_if[0].atvalid = atb_if.master_if[0].atvalid;
  assign atb_if.slave_if[0].atid    = atb_if.master_if[0].atid;
  assign atb_if.slave_if[0].atbytes = atb_if.master_if[0].atbytes;
  assign atb_if.slave_if[0].atdata  = atb_if.master_if[0].atdata;
  assign atb_if.master_if[0].atready = atb_if.slave_if[0].atready;

  assign atb_if.master_if[0].afvalid = atb_if.slave_if[0].afvalid;
  assign atb_if.slave_if[0].afready  = atb_if.master_if[0].afready;
  assign atb_if.master_if[0].syncreq = atb_if.slave_if[0].syncreq;
endmodule

`endif

