`ifndef DEBUG_ECT_ROUTE_ETF_FULL_MULTI_CHANNEL_TEST_SV
`define DEBUG_ECT_ROUTE_ETF_FULL_MULTI_CHANNEL_TEST_SV

// ==========================================
// AON ECT randomized multi-channel fanout test
// ==========================================
// The C case randomly selects 2..4 CTM channels and maps:
//   ETF.full -> CTI_AON event_in[0] -> selected channels
//   selected channels -> CTI_AON event_out[1] / ETF.trigin
//   selected channels -> CTI_AON event_out[2] / ETF.flushin
//
// This test does not use APB readback.  It checks only the source request
// and the two configured output events; per-channel checking is left to
// waveform/debug inspection because the exact random mask is not visible
// to the UVM side.
// ==========================================

class debug_ect_route_etf_full_multi_channel extends aon_base_test;
  `uvm_component_utils(debug_ect_route_etf_full_multi_channel)

  function new(string name = "debug_ect_route_etf_full_multi_channel",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_MULTI", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_MULTI",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; source event cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    // Source request is observed first.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(0),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    // Both configured output routes must fire.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_OUT), .index(1),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_OUT), .index(1),
      .expected_value(1'b0), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_OUT), .index(2),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_OUT), .index(2),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
    if (!pulse_seq.randomize() with {
          loc          == ECT_AON_CTI_EVT_IN;
          index        == 0;
          value        == 1'b1;
          pulse_cycles == 2;
        }) begin
      `uvm_error("ECT_MULTI", "Failed to randomize ETF.full multi-channel pulse sequence")
    end

    pulse_seq.start(env.ect_agent.sequencer);

    repeat (1200) @(posedge env.ect_cfg.vif.clk);

    `uvm_info("ECT_MULTI",
      "ETF.full -> random channel set -> ETF.trigin/flushin completed", UVM_MEDIUM)
  endtask
endclass

`endif
