`ifndef ECT_AON_IF_SV
`define ECT_AON_IF_SV

// ------------------------------------------------------------------
// AON Embedded Cross Trigger (ECT) signal interface.
//
// Signal groups are based on ECT_Event_Mapping.xlsx / sys_aon:
//   - CTI_AON event inputs/outputs
//   - CTI_M52 event inputs/outputs
//   - CTM channel paths connected to CTI_AON, CTI_M52, and top async CTM
//
// The driver/modport only drives injection-side paths.  Check/monitor paths
// are inputs so the same interface can observe DUT-generated events.
// ------------------------------------------------------------------

interface ect_aon_if(input logic clk, input logic rst_n);

  // CTI_AON local trigger events.
  // evt_in : subsystem/IP events into CTI_AON
  // evt_out: CTI_AON generated events to IP sinks
  logic [9:0]  cti_aon_evt_in;
  logic [14:0] cti_aon_evt_out;

  // CTI_M52 local trigger events.
  logic [5:0] cti_m52_evt_in;
  logic [7:0] cti_m52_evt_out;

  // CTM channel paths for CTI_AON.
  logic [15:0] ctm_aon_ch_in;
  logic [15:0] ctm_aon_ch_out;

  // CTM channel paths for CTI_M52.
  logic [3:0] ctm_m52_ch_in;
  logic [3:0] ctm_m52_ch_out;

  // CTM channel paths bridged to the top-level async CTM tree.
  logic [15:0] ctm_top_ch_in;
  logic [15:0] ctm_top_ch_out;

  // Dedicated handshake acknowledgement view.  These are kept separate from
  // packed event vectors because ECT_Event_Mapping marks several events as
  // handshake type and later checker logic may need req/ack correlation.
  logic hifi_cti_out_ack;
  logic hifi_break_out_ack;
  logic hifi_cti_in_ack;
  logic hifi_break_in_ack;
  logic tbu_pmusnapshot_ack;

  modport drv_mp(
    input  clk,
    input  rst_n,
    output cti_aon_evt_in,
    output cti_m52_evt_in,
    output ctm_aon_ch_in,
    output ctm_m52_ch_in,
    output ctm_top_ch_in,
    input  cti_aon_evt_out,
    input  cti_m52_evt_out,
    input  ctm_aon_ch_out,
    input  ctm_m52_ch_out,
    input  ctm_top_ch_out,
    input  hifi_cti_out_ack,
    input  hifi_break_out_ack,
    input  hifi_cti_in_ack,
    input  hifi_break_in_ack,
    input  tbu_pmusnapshot_ack
  );

  modport mon_mp(
    input clk,
    input rst_n,
    input cti_aon_evt_in,
    input cti_aon_evt_out,
    input cti_m52_evt_in,
    input cti_m52_evt_out,
    input ctm_aon_ch_in,
    input ctm_aon_ch_out,
    input ctm_m52_ch_in,
    input ctm_m52_ch_out,
    input ctm_top_ch_in,
    input ctm_top_ch_out,
    input hifi_cti_out_ack,
    input hifi_break_out_ack,
    input hifi_cti_in_ack,
    input hifi_break_in_ack,
    input tbu_pmusnapshot_ack
  );

endinterface

`endif
