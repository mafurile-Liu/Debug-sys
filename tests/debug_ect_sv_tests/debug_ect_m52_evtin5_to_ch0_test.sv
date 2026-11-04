`ifndef debug_ect_m52_evtin5_to_ch0_TEST_SV
`define debug_ect_m52_evtin5_to_ch0_TEST_SV

// ==========================================
// M52 CTI event-in route test for event_in5
// ==========================================
// Route programmed by C:
  event_in[5] -> channel[0]

This case covers the remaining connected M52 input trigger.  It checks only
the input-to-channel path; no output route is enabled.
// ==========================================

class debug_ect_m52_evtin5_to_ch0 extends aon_base_test;
  `uvm_component_utils(debug_ect_m52_evtin5_to_ch0)

  function new(string name = "debug_ect_m52_evtin5_to_ch0",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_M52_EVTIN5", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_M52_EVTIN5",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; M52 source event cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    // Source trigger and M52 CTI channel output.
    env.ect_scoreboard.expect_event(
      .loc(ECT_M52_CTI_EVT_IN), .index(5),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_M52_CTI_EVT_IN), .index(5),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_M52_CH_IN), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_M52_CH_IN), .index(0),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_M52_CH_OUT), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_M52_CH_OUT), .index(0),
      .expected_value(1'b0), .timeout_cycles(1000)
    );

    // This event-in-only case does not program an output route.
    for (int unsigned out_idx = 0; out_idx < 8; out_idx++) begin
      env.ect_scoreboard.expect_no_event(
        .loc(ECT_M52_CTI_EVT_OUT), .index(out_idx),
        .forbidden_value(1'b1), .timeout_cycles(1000)
      );
    end

    // Crosstalk: no other M52 channel may pulse.
    for (int unsigned ch = 1; ch < 4; ch++) begin
      env.ect_scoreboard.expect_no_event(
        .loc(ECT_CTM_M52_CH_IN), .index(ch),
        .forbidden_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_no_event(
        .loc(ECT_CTM_M52_CH_OUT), .index(ch),
        .forbidden_value(1'b1), .timeout_cycles(1000)
      );
    end

    pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
    if (!pulse_seq.randomize() with {
          loc          == ECT_M52_CTI_EVT_IN;
          index        == 5;
          value        == 1'b1;
          pulse_cycles == 2;
        }) begin
      `uvm_error("ECT_M52_EVTIN5", "Failed to randomize M52 event_in5 pulse sequence")
    end

    pulse_seq.start(env.ect_agent.sequencer);

    repeat (1200) @(posedge env.ect_cfg.vif.clk);

    `uvm_info("ECT_M52_EVTIN5", "M52 event_in5 -> channel0 completed", UVM_MEDIUM)
  endtask
endclass

`endif