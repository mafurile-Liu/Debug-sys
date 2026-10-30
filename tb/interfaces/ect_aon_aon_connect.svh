`ifndef ECT_AON_AON_CONNECT_SVH
`define ECT_AON_AON_CONNECT_SVH

// ------------------------------------------------------------------
// Connect ect_aon_if to the AON ECT hierarchy from
// ECT_Event_Mapping.xlsx / sys_aon.
//
// Usage:
//   1. Instantiate ect_aon_if ect_if(...) in the top-level TB.
//   2. Include this file in the same top-level module.
//
// Connection policy:
//   - Injection-side IP/CTI inputs use force so the agent can drive them.
//   - Observation-side CTI outputs and acks use assign.
//   - Channel in is forced; channel out is observed.
// ------------------------------------------------------------------

// ---------------- CTI_AON event_in: agent injection ----------------
initial begin
  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etf_dbg_aon.full
    = ect_if.cti_aon_evt_in[0];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etf_dbg_aon.acqcomp
    = ect_if.cti_aon_evt_in[1];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etf_dbg_aon.flushcomp
    = ect_if.cti_aon_evt_in[2];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etr_dbg_aon.full
    = ect_if.cti_aon_evt_in[3];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etr_dbg_aon.acqcomp
    = ect_if.cti_aon_evt_in[4];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etr_dbg_aon.flushcomp
    = ect_if.cti_aon_evt_in[5];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.CrossTriggerOut
    = ect_if.cti_aon_evt_in[6];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.BreakOut
    = ect_if.cti_aon_evt_in[7];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_out[0]
    = ect_if.cti_aon_evt_in[8];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_out[1]
    = ect_if.cti_aon_evt_in[9];
end

// ---------------- CTI_AON event_out: observation ----------------
assign ect_if.cti_aon_evt_out[0] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_dap_dbg_aon.u_css600_dpreceiver_dap.dp_eventstatus;

assign ect_if.cti_aon_evt_out[1] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etf_dbg_aon.trigin;

assign ect_if.cti_aon_evt_out[2] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etf_dbg_aon.flushin;

assign ect_if.cti_aon_evt_out[3] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etr_dbg_aon.trigin;

assign ect_if.cti_aon_evt_out[4] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_trace_dbg_aon.u_css600_tmc_etr_dbg_aon.flushin;

assign ect_if.cti_aon_evt_out[5] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_cfg1_wrapper.u_tsgen.u_css600_tsgen.halt_req;

assign ect_if.cti_aon_evt_out[6] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_cfg1_wrapper.u_tsgen.u_css600_tsgen.restart_req;

assign ect_if.cti_aon_evt_out[7] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.CrossTriggerIn;

assign ect_if.cti_aon_evt_out[8] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.BreakIn;

assign ect_if.cti_aon_evt_out[9] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_in[0];

assign ect_if.cti_aon_evt_out[10] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_in[1];

assign ect_if.cti_aon_evt_out[11] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_in[2];

assign ect_if.cti_aon_evt_out[12] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_axi_bus_monitor.cti_trig_in[3];

assign ect_if.cti_aon_evt_out[13] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_dbg_bus_monitor_mcu2bus.cti_trig_i;

assign ect_if.cti_aon_evt_out[14] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_tbu_aon.pmusnapshot_req;

// ---------------- CTI_AON handshake ack: observation ----------------
assign ect_if.hifi_cti_out_ack =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.CrossTriggerOutAck;

assign ect_if.hifi_break_out_ack =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.BreakOutAck;

assign ect_if.hifi_cti_in_ack =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.CrossTriggerInAck;

assign ect_if.hifi_break_in_ack =
  sys_aon_pwr_wrap.u_sys_aon_top.u_dsp_wrapper.u_Xm_hifi5s_ao_7Xtsubsystem.BreakInAck;

assign ect_if.tbu_pmusnapshot_ack =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_mem_noc_out.u_tbu_aon.pmusnapshot_ack;

assign ect_if.cti_aon_ch_out =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_ect_dbg_aon.u_css600_cti_com.channel_out;

// Observe the AON CTM channel view as well: ch_in receives from CTI_AON,
// ch_out drives back to CTI_AON.  Both are useful for route/crosstalk checks.
assign ect_if.ctm_aon_ch_in =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_ect_dbg_aon.u_css600_cti_com.channel_out;

assign ect_if.ctm_aon_ch_out =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_ect_dbg_aon.u_css600_cti_com.channel_in;

// ---------------- CTI_M52 event_in: agent injection ----------------
initial begin
  force sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.core_halted_rise
    = ect_if.cti_m52_evt_in[0];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.dwt_cmpmatch_i[3:2]
    = ect_if.cti_m52_evt_in[3:2];

  force sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.etm_cti_extout_i[1:0]
    = ect_if.cti_m52_evt_in[5:4];
end

// ---------------- CTI_M52 event_out: observation ----------------
assign ect_if.cti_m52_evt_out[0] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_core_edbgrq_o;

assign ect_if.cti_m52_evt_out[1] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_core_restart_o;

assign ect_if.cti_m52_evt_out[3:2] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_ext_irq_o[1:0];

assign ect_if.cti_m52_evt_out[7:4] =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_etm_extin_o[3:0];

assign sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_core_trigout_o[7:4] =
  ect_if.cti_m52_evt_out[7:4];

assign ect_if.cti_m52_ch_out =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_ext_chout_o;

assign ect_if.ctm_m52_ch_in =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.cti_ext_chout_o;

assign ect_if.ctm_m52_ch_out =
  sys_aon_pwr_wrap.u_sys_aon_top.u_aon_m52_wrapper.u_MIZAR.u_pdcore.u_core_wrapper.gen_cti.u_cti.ext_cti_chin_i;

assign ect_if.ctm_top_ch_out =
  sys_aon_pwr_wrap.u_sys_aon_top.u_sys_dbg_aon.u_ect_dbg_aon.ctm_channel_out[47:32];

`endif
