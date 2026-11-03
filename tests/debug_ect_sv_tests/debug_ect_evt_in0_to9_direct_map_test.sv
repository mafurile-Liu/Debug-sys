`ifndef DEBUG_ECT_EVT_IN0_TO9_DIRECT_MAP_TEST_SV
`define DEBUG_ECT_EVT_IN0_TO9_DIRECT_MAP_TEST_SV

// ==========================================
// AON ECT event_in[0..9] direct mapping test
// ==========================================
// The C case programs:
//   event_in[i] -> channel[i]
//   channel[i]  -> event_out[1] / ETF.trigin
//
// This test injects event_in[0..9] one at a time.  For each event it checks:
//   1. the source event pulse
//   2. the directly mapped CTI_AON channel output
//   3. no loopback channel return into CTI_AON
//   4. M52 CTM fanout for channel0..3 only
//   5. top CTM fanout for all mapped channels
//   6. ETF.trigin output
//   7. crosstalk on unused channels/outputs
//   8. M52 CTI remains inactive because it is not configured
// ==========================================

class debug_ect_evt_in0_to9_direct_map extends aon_base_test;
  `uvm_component_utils(debug_ect_evt_in0_to9_direct_map)

  function new(string name = "debug_ect_evt_in0_to9_direct_map",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;
    int unsigned evt_idx;
    int unsigned ch;
    int unsigned out_idx;
    int unsigned m52_idx;
    int unsigned m52_out_idx;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_DIRECT", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_AON_ENABLE_SOURCE_FORCE")) begin
      `uvm_fatal("ECT_DIRECT",
        "Missing +ECT_AON_ENABLE_SOURCE_FORCE; source event cannot enter DUT")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (evt_idx = 0; evt_idx < 10; evt_idx++) begin
      // Source request and directly mapped CTI_AON channel output.
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_IN), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_AON_CH_IN), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // CTM_AON_CH_OUT is CTI_AON.channel_in, i.e. the return direction from
      // CTM to CTI_AON.  This case sources the event from CTI_AON itself and
      // the current topology does not loop the channel back to the source CTI,
      // so no return channel pulse is expected on any index.
      for (ch = 0; ch < 16; ch++) begin
        env.ect_scoreboard.expect_no_event(
          .loc(ECT_CTM_AON_CH_OUT), .index(ch),
          .forbidden_value(1'b1), .timeout_cycles(1000)
        );
      end

      // M52 CTM fanout.  CTI_M52 only has channel0..3, so only event_in0..3
      // can be observed here.  Event4..9 must not appear on M52.
      if (evt_idx < 4) begin
        env.ect_scoreboard.expect_event(
          .loc(ECT_CTM_M52_CH_OUT), .index(evt_idx),
          .expected_value(1'b1), .timeout_cycles(1000)
        );
        env.ect_scoreboard.expect_event(
          .loc(ECT_CTM_M52_CH_OUT), .index(evt_idx),
          .expected_value(1'b0), .timeout_cycles(1000)
        );
      end

      for (m52_idx = 0; m52_idx < 4; m52_idx++) begin
        if ((evt_idx >= 4) || (m52_idx != evt_idx)) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_M52_CH_OUT), .index(m52_idx),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      // Top CTM fanout is 16-bit wide and receives all direct-mapped channels.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_TOP_CH_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(1),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_AON_CTI_EVT_OUT), .index(1),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // Crosstalk check: only the directly mapped channel may pulse.
      for (ch = 0; ch < 16; ch++) begin
        if (ch != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_AON_CH_IN), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_TOP_CH_OUT), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      // Output crosstalk check: only ETF.trigin is configured, so no other
      // CTI_AON event output may pulse.
      for (out_idx = 0; out_idx < 15; out_idx++) begin
        if (out_idx != 1) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_AON_CTI_EVT_OUT), .index(out_idx),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      // M52 CTI is intentionally not configured and is not driven in this
      // case, so neither its raw channel output nor its local event outputs
      // may activate.
      for (m52_idx = 0; m52_idx < 4; m52_idx++) begin
        env.ect_scoreboard.expect_no_event(
          .loc(ECT_CTM_M52_CH_IN), .index(m52_idx),
          .forbidden_value(1'b1), .timeout_cycles(1000)
        );
      end

      for (m52_out_idx = 0; m52_out_idx < 8; m52_out_idx++) begin
        env.ect_scoreboard.expect_no_event(
          .loc(ECT_M52_CTI_EVT_OUT), .index(m52_out_idx),
          .forbidden_value(1'b1), .timeout_cycles(1000)
        );
      end

      pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
      if (!pulse_seq.randomize() with {
            loc          == ECT_AON_CTI_EVT_IN;
            index        == evt_idx;
            value        == 1'b1;
            pulse_cycles == 2;
          }) begin
        `uvm_error("ECT_DIRECT",
          $sformatf("Failed to randomize event_in%0d pulse sequence", evt_idx))
      end

      pulse_seq.start(env.ect_agent.sequencer);

      // Keep enough cycles for the routed output pulse and no-event windows.
      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_DIRECT",
        $sformatf("event_in%0d -> channel%0d -> ETF.trigin completed", evt_idx, evt_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
