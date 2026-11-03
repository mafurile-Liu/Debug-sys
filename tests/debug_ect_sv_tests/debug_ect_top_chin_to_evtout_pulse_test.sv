`ifndef DEBUG_ECT_TOP_CHIN_TO_EVTOUT_PULSE_TEST_SV
`define DEBUG_ECT_TOP_CHIN_TO_EVTOUT_PULSE_TEST_SV

// ==========================================
// AON ECT CTM-top-channel input to event output test
// ==========================================
// The C case maps non-handshake channels directly:
//   channel[i] -> CTI_AON event_out[i]
// where i is one of 0..6 and 9..13.  This UVM test injects each selected
// top-CTM channel and checks the corresponding event output.
// ==========================================

class debug_ect_top_chin_to_evtout_pulse extends aon_base_test;
  `uvm_component_utils(debug_ect_top_chin_to_evtout_pulse)

  local int unsigned pulse_out_idx[12] = '{
    0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13
  };

  function new(string name = "debug_ect_top_chin_to_evtout_pulse",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;
    int unsigned seq_idx;
    int unsigned evt_idx;
    int unsigned ch;
    int unsigned out_idx;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_TOP_PULSE", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_TOP_PULSE",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; top channel input cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (seq_idx = 0; seq_idx < 12; seq_idx++) begin
      evt_idx = pulse_out_idx[seq_idx];

      // Source channel request and CTI_AON channel input.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // The directly mapped CTI_AON event output must pulse.
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // Only the selected top channel and AON channel input may pulse.
      for (ch = 0; ch < 16; ch++) begin
        if (ch != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_TOP_CH_IN), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_AON_CH_OUT), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      // Only the selected AON event output may pulse.
      for (out_idx = 0; out_idx < 15; out_idx++) begin
        if (out_idx != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_AON_CTI_EVT_OUT), .index(out_idx),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
      if (!pulse_seq.randomize() with {
            loc          == ECT_CTM_TOP_CH_IN;
            index        == evt_idx;
            value        == 1'b1;
            pulse_cycles == 2;
          }) begin
        `uvm_error("ECT_TOP_PULSE",
          $sformatf("Failed to randomize top channel%0d pulse sequence", evt_idx))
      end

      pulse_seq.start(env.ect_agent.sequencer);

      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_TOP_PULSE",
        $sformatf("top channel%0d -> AON event_out%0d completed", evt_idx, evt_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
