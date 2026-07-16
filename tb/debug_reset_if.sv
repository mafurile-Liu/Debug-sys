`ifndef DEBUG_RESET_IF_SV
`define DEBUG_RESET_IF_SV

interface debug_reset_if(input logic clk);
  logic reset_n = 1'b1;

  modport seq_mp(input clk, output reset_n);
endinterface

`endif

