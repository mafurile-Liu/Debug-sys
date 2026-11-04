`ifndef debug_ect_evtin7_hs_to_ch15_TEST_SV
`define debug_ect_evtin7_hs_to_ch15_TEST_SV

// ==========================================
// Dedicated AON ECT handshake route test
// ==========================================
// Route:
//   CTI_AON event_in[7] (BreakOut)
//     -> channel[15]
//
// This trigger is handshake type.  The sequence must observe BreakOutAck;
// a missing ack is reported as an error by the ECT driver.
// ==========================================

class debug_ect_evtin7_hs_to_ch15 extends aon_base_test;
  `uvm_component_utils(debug_ect_evtin7_hs_to_ch15)

  function new(string name = "debug_ect_evtin7_hs_to_ch15",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_handshake_sequence handshake_seq;
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

    // Handshake request must be observed by the monitor.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(7),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(7),
      .expected_value(1'b0), .timeout_cycles(2000)
    );

    // The request maps only to channel15.
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_IN), .index(15),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_IN), .index(15),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    // The handshake ack is mandatory.  The driver also raises an error if
    // this ack does not appear before its timeout.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_ACK_HIFI_BREAK_OUT), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_ACK_HIFI_BREAK_OUT), .index(0),
      .expected_value(1'b0), .timeout_cycles(2000)
    );

    // Crosstalk: no other CTI_AON channel may pulse.
    for (ch = 0; ch < 16; ch++) begin
      if (ch != 15) begin
        env.ect_scoreboard.expect_no_event(
          .loc(ECT_CTM_AON_CH_IN), .index(ch),
          .forbidden_value(1'b1), .timeout_cycles(2000)
        );
      end
    end

    handshake_seq = ect_aon_handshake_sequence::type_id::create("handshake_seq");
    if (!handshake_seq.randomize() with {
          loc            == ECT_AON_CTI_EVT_IN;
          index          == 7;
          timeout_cycles == 1000;
        }) begin
      `uvm_error("ECT_HS", "Failed to randomize handshake sequence")
    end

    handshake_seq.start(env.ect_agent.sequencer);

    repeat (1200) @(posedge env.ect_cfg.vif.clk);

    `uvm_info("ECT_HS",
      $sformatf("event_in7 handshake -> channel15 completed"), UVM_MEDIUM)
  endtask
endclass

`endif
