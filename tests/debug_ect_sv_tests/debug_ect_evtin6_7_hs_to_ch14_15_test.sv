`ifndef DEBUG_ECT_EVTIN6_7_HS_TO_CH14_15_TEST_SV
`define DEBUG_ECT_EVTIN6_7_HS_TO_CH14_15_TEST_SV

// ==========================================
// Dedicated AON ECT handshake route test
// ==========================================
// Routes:
//   event_in[6] / CrossTriggerOut -> channel[14] -> CrossTriggerOutAck
//   event_in[7] / BreakOut        -> channel[15] -> BreakOutAck
//
// The triggers are handshake type.  Each sequence must observe its ack;
// a missing ack is reported as an error by the ECT driver.
// ==========================================

class debug_ect_evtin6_7_hs_to_ch14_15 extends aon_base_test;
  `uvm_component_utils(debug_ect_evtin6_7_hs_to_ch14_15)

  local int unsigned hs_src_idx[2] = '{6, 7};
  local int unsigned hs_ch_idx[2]  = '{14, 15};

  function new(string name = "debug_ect_evtin6_7_hs_to_ch14_15",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_handshake_sequence handshake_seq;
    int unsigned seq_idx;
    int unsigned evt_idx;
    int unsigned ch_idx;
    int unsigned ch;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_HS", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_HS",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; source event cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (seq_idx = 0; seq_idx < 2; seq_idx++) begin
      evt_idx = hs_src_idx[seq_idx];
      ch_idx  = hs_ch_idx[seq_idx];

      // Handshake request must be observed by the monitor.
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(2000)
      );

      // The request maps only to the selected channel.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_IN), .index(ch_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_IN), .index(ch_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // The handshake ack is mandatory.  The driver also raises an error if
      // this ack does not appear before its timeout.
      if (evt_idx == 6) begin
        env.ect_scoreboard.expect_event(
          .loc(ECT_AON_ACK_HIFI_CTI_OUT), .index(0),
          .expected_value(1'b1), .timeout_cycles(1000)
        );
        env.ect_scoreboard.expect_event(
          .loc(ECT_AON_ACK_HIFI_CTI_OUT), .index(0),
          .expected_value(1'b0), .timeout_cycles(2000)
        );
      end
      else begin
        env.ect_scoreboard.expect_event(
          .loc(ECT_AON_ACK_HIFI_BREAK_OUT), .index(0),
          .expected_value(1'b1), .timeout_cycles(1000)
        );
        env.ect_scoreboard.expect_event(
          .loc(ECT_AON_ACK_HIFI_BREAK_OUT), .index(0),
          .expected_value(1'b0), .timeout_cycles(2000)
        );
      end

      // Crosstalk: no other CTI_AON channel may pulse.
      for (ch = 0; ch < 16; ch++) begin
        if (ch != ch_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_AON_CH_IN), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(2000)
          );
        end
      end

      handshake_seq = ect_aon_handshake_sequence::type_id::create("handshake_seq");
      if (!handshake_seq.randomize() with {
            loc            == ECT_AON_CTI_EVT_IN;
            index          == evt_idx;
            timeout_cycles == 1000;
          }) begin
        `uvm_error("ECT_HS", "Failed to randomize handshake sequence")
      end

      handshake_seq.start(env.ect_agent.sequencer);

      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_HS",
        $sformatf("event_in%0d handshake -> channel%0d completed", evt_idx, ch_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
