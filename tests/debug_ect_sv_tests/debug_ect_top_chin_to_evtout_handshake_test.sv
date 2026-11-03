`ifndef DEBUG_ECT_TOP_CHIN_TO_EVTOUT_HANDSHAKE_TEST_SV
`define DEBUG_ECT_TOP_CHIN_TO_EVTOUT_HANDSHAKE_TEST_SV

// ==========================================
// AON ECT CTM-top-channel input to handshake output test
// ==========================================
// The C case maps handshake channels directly:
//   channel[7]  -> event_out[7]  / HiFi CrossTriggerIn
//   channel[8]  -> event_out[8]  / HiFi BreakIn
//   channel[14] -> event_out[14] / TBU pmusnapshot_req
//
// The UVM agent holds the selected channel high until the mapped ack is
// observed, so handshake semantics are exercised explicitly.
// ==========================================

class debug_ect_top_chin_to_evtout_handshake extends aon_base_test;
  `uvm_component_utils(debug_ect_top_chin_to_evtout_handshake)

  local int unsigned handshake_out_idx[3] = '{7, 8, 14};

  function new(string name = "debug_ect_top_chin_to_evtout_handshake",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_handshake_sequence handshake_seq;
    int unsigned seq_idx;
    int unsigned evt_idx;
    int unsigned ch;
    int unsigned out_idx;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_TOP_HS", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_TOP_HS",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; top channel input cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (seq_idx = 0; seq_idx < 3; seq_idx++) begin
      evt_idx = handshake_out_idx[seq_idx];

      // The driver holds the source channel until the mapped ack is seen.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(2000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(2000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(2000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(2000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(2000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(2000)
      );

      // Only the selected source and AON channel input may pulse.
      for (ch = 0; ch < 16; ch++) begin
        if (ch != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_TOP_CH_IN), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(2000)
          );
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_AON_CH_OUT), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(2000)
          );
        end
      end

      // Only the selected handshake output may pulse.
      for (out_idx = 0; out_idx < 15; out_idx++) begin
        if (out_idx != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_AON_CTI_EVT_OUT), .index(out_idx),
            .forbidden_value(1'b1), .timeout_cycles(2000)
          );
        end
      end

      handshake_seq = ect_aon_handshake_sequence::type_id::create("handshake_seq");
      if (!handshake_seq.randomize() with {
            loc            == ECT_CTM_TOP_CH_IN;
            index          == evt_idx;
            timeout_cycles == 1000;
          }) begin
        `uvm_error("ECT_TOP_HS",
          $sformatf("Failed to randomize top channel%0d handshake sequence", evt_idx))
      end

      handshake_seq.start(env.ect_agent.sequencer);

      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_TOP_HS",
        $sformatf("top channel%0d -> AON handshake event_out%0d completed", evt_idx, evt_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
