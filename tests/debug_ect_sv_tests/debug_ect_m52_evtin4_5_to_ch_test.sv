`ifndef debug_ect_m52_evtin4_5_to_ch_TEST_SV
`define debug_ect_m52_evtin4_5_to_ch_TEST_SV

// ==========================================
// M52 CTI event-in route test group 4/5
// ==========================================
// Routes programmed by C (etm_cti_extout_i[1:0] drives event_in[5:4]):
//   event_in[4] -> channel[0]
//   event_in[5] -> channel[1]

// This case checks only the input-to-channel path; no output route is enabled.
// ==========================================

class debug_ect_m52_evtin4_5_to_ch extends aon_base_test;
  `uvm_component_utils(debug_ect_m52_evtin4_5_to_ch)

  function new(string name = "debug_ect_m52_evtin4_5_to_ch",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;
    int unsigned seq_idx;
    int unsigned evt_idx;
    int unsigned ch_idx;
    int unsigned ch;
    int unsigned out_idx;
    int unsigned m52_evt_in_idx[2] = '{4, 5};

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_M52_EVTIN45", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_M52_EVTIN45",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; M52 source event cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (seq_idx = 0; seq_idx < 2; seq_idx++) begin
      evt_idx = m52_evt_in_idx[seq_idx];
      ch_idx  = seq_idx;

      // Source trigger and M52 CTI channel output.
      env.ect_scoreboard.expect_event(
        .loc(ECT_M52_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_M52_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_IN), .index(ch_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_IN), .index(ch_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // CTM returns the selected channel to M52 CTI channel input.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_OUT), .index(ch_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_OUT), .index(ch_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // This event-in-only case does not program an output route.
      for (out_idx = 0; out_idx < 8; out_idx++) begin
        env.ect_scoreboard.expect_no_event(
          .loc(ECT_M52_CTI_EVT_OUT), .index(out_idx),
          .forbidden_value(1'b1), .timeout_cycles(1000)
        );
      end

      // Crosstalk: only the selected source channel and return channel may
      // pulse.
      for (ch = 0; ch < 4; ch++) begin
        if (ch != ch_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_M52_CH_IN), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_M52_CH_OUT), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
      if (!pulse_seq.randomize() with {
            loc          == ECT_M52_CTI_EVT_IN;
            index        == evt_idx;
            value        == 1'b1;
            pulse_cycles == 2;
          }) begin
        `uvm_error("ECT_M52_EVTIN45",
          $sformatf("Failed to randomize M52 event_in%0d pulse sequence", evt_idx))
      end

      pulse_seq.start(env.ect_agent.sequencer);

      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_M52_EVTIN45",
        $sformatf("M52 event_in%0d -> channel%0d completed", evt_idx, ch_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
