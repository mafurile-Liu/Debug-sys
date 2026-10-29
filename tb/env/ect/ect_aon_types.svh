`ifndef ECTAONTYPES_SVH
`define ECTAONTYPES_SVH

  typedef enum int unsigned {
    ECT_AON_CTI_EVT_IN   = 0,
    ECT_AON_CTI_EVT_OUT  = 1,
    ECT_M52_CTI_EVT_IN   = 2,
    ECT_M52_CTI_EVT_OUT  = 3,
    ECT_CTM_AON_CH_IN    = 4,
    ECT_CTM_AON_CH_OUT   = 5,
    ECT_CTM_M52_CH_IN    = 6,
    ECT_CTM_M52_CH_OUT   = 7,
    ECT_CTM_TOP_CH_IN    = 8,
    ECT_CTM_TOP_CH_OUT   = 9,
    ECT_AON_ACK_HIFI_CTI_OUT  = 10,
    ECT_AON_ACK_HIFI_BREAK_OUT = 11,
    ECT_AON_ACK_HIFI_CTI_IN   = 12,
    ECT_AON_ACK_HIFI_BREAK_IN = 13,
    ECT_AON_ACK_TBU           = 14
  } ect_aon_loc_e;

  typedef enum int unsigned {
    ECT_OP_PULSE = 0,
    ECT_OP_LEVEL = 1,
    ECT_OP_HANDSHAKE = 2
  } ect_aon_op_e;

  typedef enum int unsigned {
    ECT_PAIR_AON_CTI_HIFI_CTI_OUT   = 0,
    ECT_PAIR_AON_CTI_HIFI_BREAK_OUT = 1,
    ECT_PAIR_AON_CTI_HIFI_CTI_IN    = 2,
    ECT_PAIR_AON_CTI_HIFI_BREAK_IN  = 3,
    ECT_PAIR_AON_CTI_TBU            = 4
  } ect_aon_pair_e;

  // Widths come from the current ECT_Event_Mapping/sys_aon interface view.
  function automatic int unsigned ect_aon_loc_width(ect_aon_loc_e loc);
    case (loc)
      ECT_AON_CTI_EVT_IN  : return 10;
      ECT_AON_CTI_EVT_OUT : return 15;
      ECT_M52_CTI_EVT_IN  : return 6;
      ECT_M52_CTI_EVT_OUT : return 8;
      ECT_CTM_AON_CH_IN   : return 16;
      ECT_CTM_AON_CH_OUT  : return 16;
      ECT_CTM_M52_CH_IN   : return 4;
      ECT_CTM_M52_CH_OUT  : return 4;
      ECT_CTM_TOP_CH_IN   : return 16;
      ECT_CTM_TOP_CH_OUT  : return 16;
      ECT_AON_ACK_HIFI_CTI_OUT  : return 1;
      ECT_AON_ACK_HIFI_BREAK_OUT : return 1;
      ECT_AON_ACK_HIFI_CTI_IN   : return 1;
      ECT_AON_ACK_HIFI_BREAK_IN : return 1;
      ECT_AON_ACK_TBU           : return 1;
      default             : return 0;
    endcase
  endfunction

  function automatic bit ect_aon_ack_exists(
    ect_aon_loc_e loc,
    int unsigned   index
  );
    case (loc)
      ECT_AON_CTI_EVT_IN:
        return (index == 6) || (index == 7);
      ECT_AON_CTI_EVT_OUT:
        return (index == 7) || (index == 8) || (index == 14);
      default: return 1'b0;
    endcase
  endfunction

  function automatic logic ect_aon_sample_ack(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index
  );
    case ({loc, index})
      {ECT_AON_CTI_EVT_IN,  6} : return vif.hifi_cti_out_ack;
      {ECT_AON_CTI_EVT_IN,  7} : return vif.hifi_break_out_ack;
      {ECT_AON_CTI_EVT_OUT, 7} : return vif.hifi_cti_in_ack;
      {ECT_AON_CTI_EVT_OUT, 8} : return vif.hifi_break_in_ack;
      {ECT_AON_CTI_EVT_OUT, 14}: return vif.tbu_pmusnapshot_ack;
      default: return 1'b0;
    endcase
  endfunction

  function automatic ect_aon_pair_e ect_aon_pair_for_request(
    ect_aon_loc_e loc,
    int unsigned   index
  );
    case ({loc, index})
      {ECT_AON_CTI_EVT_IN,  6} : return ECT_PAIR_AON_CTI_HIFI_CTI_OUT;
      {ECT_AON_CTI_EVT_IN,  7} : return ECT_PAIR_AON_CTI_HIFI_BREAK_OUT;
      {ECT_AON_CTI_EVT_OUT, 7} : return ECT_PAIR_AON_CTI_HIFI_CTI_IN;
      {ECT_AON_CTI_EVT_OUT, 8} : return ECT_PAIR_AON_CTI_HIFI_BREAK_IN;
      {ECT_AON_CTI_EVT_OUT, 14}: return ECT_PAIR_AON_CTI_TBU;
      default: return ECT_PAIR_AON_CTI_HIFI_CTI_OUT;
    endcase
  endfunction

  function automatic ect_aon_pair_e ect_aon_pair_for_ack(
    ect_aon_loc_e loc
  );
    case (loc)
      ECT_AON_ACK_HIFI_CTI_OUT  : return ECT_PAIR_AON_CTI_HIFI_CTI_OUT;
      ECT_AON_ACK_HIFI_BREAK_OUT : return ECT_PAIR_AON_CTI_HIFI_BREAK_OUT;
      ECT_AON_ACK_HIFI_CTI_IN   : return ECT_PAIR_AON_CTI_HIFI_CTI_IN;
      ECT_AON_ACK_HIFI_BREAK_IN : return ECT_PAIR_AON_CTI_HIFI_BREAK_IN;
      ECT_AON_ACK_TBU           : return ECT_PAIR_AON_CTI_TBU;
      default: return ECT_PAIR_AON_CTI_HIFI_CTI_OUT;
    endcase
  endfunction

  function automatic logic ect_aon_sample_bit(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index
  );
    case (loc)
      ECT_AON_CTI_EVT_IN  : return vif.cti_aon_evt_in[index];
      ECT_AON_CTI_EVT_OUT : return vif.cti_aon_evt_out[index];
      ECT_M52_CTI_EVT_IN  : return vif.cti_m52_evt_in[index];
      ECT_M52_CTI_EVT_OUT : return vif.cti_m52_evt_out[index];
      ECT_CTM_AON_CH_IN   : return vif.ctm_aon_ch_in[index];
      ECT_CTM_AON_CH_OUT  : return vif.ctm_aon_ch_out[index];
      ECT_CTM_M52_CH_IN   : return vif.ctm_m52_ch_in[index];
      ECT_CTM_M52_CH_OUT  : return vif.ctm_m52_ch_out[index];
      ECT_CTM_TOP_CH_IN   : return vif.ctm_top_ch_in[index];
      ECT_CTM_TOP_CH_OUT  : return vif.ctm_top_ch_out[index];
      ECT_AON_ACK_HIFI_CTI_OUT  : return vif.hifi_cti_out_ack;
      ECT_AON_ACK_HIFI_BREAK_OUT : return vif.hifi_break_out_ack;
      ECT_AON_ACK_HIFI_CTI_IN   : return vif.hifi_cti_in_ack;
      ECT_AON_ACK_HIFI_BREAK_IN : return vif.hifi_break_in_ack;
      ECT_AON_ACK_TBU           : return vif.tbu_pmusnapshot_ack;
      default             : return 1'bx;
    endcase
  endfunction

  function automatic void ect_aon_drive_bit(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index,
    logic              value
  );
    case (loc)
      ECT_AON_CTI_EVT_IN  : vif.cti_aon_evt_in[index]  = value;
      ECT_M52_CTI_EVT_IN  : vif.cti_m52_evt_in[index]  = value;
      ECT_CTM_AON_CH_IN   : vif.ctm_aon_ch_in[index]   = value;
      ECT_CTM_M52_CH_IN   : vif.ctm_m52_ch_in[index]   = value;
      ECT_CTM_TOP_CH_IN   : vif.ctm_top_ch_in[index]   = value;
      default: `uvm_warning("ECT_AON_DRV",
        $sformatf("Location %s is not an injection path", loc.name()))
    endcase
  endfunction

`endif
