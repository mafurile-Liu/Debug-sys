`ifndef debug_ect_m52_chin_to_evtout0_3_TEST_SV
`define debug_ect_m52_chin_to_evtout0_3_TEST_SV

// ==========================================
// M52 CTI channel-to-output route test group 0
// ==========================================
// Routes programmed by C:
//   channel[0] -> event_out[0]
//   channel[1] -> event_out[1]
//   channel[2] -> event_out[2]
//   channel[3] -> event_out[3]
// ==========================================

class debug_ect_m52_chin_to_evtout0_3 extends aon_base_test;
  `uvm_component_utils(debug_ect_m52_chin_to_evtout0_3)

  function new(string name = "debug_ect_m52_chin_to_evtout0_3",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task test_body();
    ect_aon_pulse_sequence pulse_seq;
    int unsigned seq_idx;
    int unsigned ch_idx;
    int unsigned evt_idx;
    int unsigned ch;
    int unsigned out_idx;

    if (env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_M52_EVTOUT", "AON ECT scoreboard is not available")
    end

    if (!$test$plusargs("ECT_M52_CH_IN_FORCE")) begin
      `uvm_fatal("ECT_M52_EVTOUT",
        "Missing +ECT_M52_CH_IN_FORCE; M52 channel input cannot be injected")
    end

    wait(c_test_finish == 1);
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    for (seq_idx = 0; seq_idx < 4; seq_idx++) begin
      ch_idx  = seq_idx;
      evt_idx = ch_idx + 0;

      // Source channel request is observed by the monitor.
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_IN_DRV), .index(ch_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_CTM_M52_CH_IN_DRV), .index(ch_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // The directly mapped M52 CTI event output must pulse.
      env.ect_scoreboard.expect_event(
        .loc(ECT_M52_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_event(
        .loc(ECT_M52_CTI_EVT_OUT), .index(evt_idx),
        .expected_value(1'b0), .timeout_cycles(1000)
      );

      // Crosstalk: only the selected M52 channel input may pulse.
      for (ch = 0; ch < 4; ch++) begin
        if (ch != ch_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_CTM_M52_CH_IN_DRV), .index(ch),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      // Crosstalk: no other M52 event output may pulse.
      for (out_idx = 0; out_idx < 8; out_idx++) begin
        if (out_idx != evt_idx) begin
          env.ect_scoreboard.expect_no_event(
            .loc(ECT_M52_CTI_EVT_OUT), .index(out_idx),
            .forbidden_value(1'b1), .timeout_cycles(1000)
          );
        end
      end

      pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
      if (!pulse_seq.randomize() with {
            loc          == ECT_CTM_M52_CH_IN_DRV;
            index        == ch_idx;
            value        == 1'b1;
            pulse_cycles == 2;
          }) begin
        `uvm_error("ECT_M52_EVTOUT",
          $sformatf("Failed to randomize M52 channel%0d pulse sequence", ch_idx))
      end

      pulse_seq.start(env.ect_agent.sequencer);

      repeat (1200) @(posedge env.ect_cfg.vif.clk);

      `uvm_info("ECT_M52_EVTOUT",
        $sformatf("M52 channel%0d -> event_out%0d completed", ch_idx, evt_idx),
        UVM_MEDIUM)
    end
  endtask
endclass

`endif
