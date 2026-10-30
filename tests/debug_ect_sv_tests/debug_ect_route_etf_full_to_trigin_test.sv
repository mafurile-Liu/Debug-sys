`ifndef DEBUG_ECT_ROUTE_ETF_FULL_TO_TRIGIN_TEST_SV
`define DEBUG_ECT_ROUTE_ETF_FULL_TO_TRIGIN_TEST_SV

// ==========================================
// AON ECT single-route test
// ==========================================
// Route under test:
//   ETF.full -> CTI_AON event_in[0]
//            -> channel[0]
//            -> CTI_AON event_out[1]
//            -> ETF.trigin
//
// The C case with the same name programs CTIINEN0/CTIOUTEN1/GATE/CONTROL.
// This UVM test injects event_in[0] and checks that only channel[0] pulses.
// ==========================================

class debug_ect_route_etf_full_to_trigin extends debug_port_base_test;
  `uvm_component_utils(debug_ect_route_etf_full_to_trigin)

  function new(string name = "debug_ect_route_etf_full_to_trigin",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void configure_env(debug_sys_cfg cfg);
    super.configure_env(cfg);
    cfg.enable_ect = 1'b1;
  endfunction

  virtual task main_phase(uvm_phase phase);
    ect_aon_pulse_sequence pulse_seq;
    int unsigned ch;

    phase.raise_objection(this);

    if (env.vseqr == null || env.vseqr.ect_sequencer == null ||
        env.ect_scoreboard == null) begin
      `uvm_fatal("ECT_ROUTE", "AON ECT env/sequencer/scoreboard is not available")
    end

    // Give the C configuration case time to program CTIINEN0, CTIOUTEN1,
    // GATE, and CONTROL before injecting the source event.
    repeat (2000) @(posedge env.ect_cfg.vif.clk);

    // Source request and routed channel/output pulses.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN), .index(0),
      .expected_value(1'b0), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_IN), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_IN), .index(0),
      .expected_value(1'b0), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_OUT), .index(0),
      .expected_value(1'b1), .timeout_cycles(1000)
    );
    env.ect_scoreboard.expect_event(
      .loc(ECT_CTM_AON_CH_OUT), .index(0),
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

    // Crosstalk check: no other AON CTM channel may pulse high.
    for (ch = 1; ch < 16; ch++) begin
      env.ect_scoreboard.expect_no_event(
        .loc(ECT_CTM_AON_CH_IN), .index(ch),
        .forbidden_value(1'b1), .timeout_cycles(1000)
      );
      env.ect_scoreboard.expect_no_event(
        .loc(ECT_CTM_AON_CH_OUT), .index(ch),
        .forbidden_value(1'b1), .timeout_cycles(1000)
      );
    end

    pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
    if (!pulse_seq.randomize() with {
          loc          == ECT_AON_CTI_EVT_IN;
          index        == 0;
          value        == 1'b1;
          pulse_cycles == 1;
        }) begin
      `uvm_error("ECT_ROUTE", "Failed to randomize ETF.full pulse sequence")
    end

    pulse_seq.start(env.vseqr.ect_sequencer);

    // Keep enough cycles for the routed output pulse and all no-event windows.
    repeat (1200) @(posedge env.ect_cfg.vif.clk);

    `uvm_info("ECT_ROUTE", "ETF.full -> channel0 -> ETF.trigin route completed", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask
endclass

`endif
