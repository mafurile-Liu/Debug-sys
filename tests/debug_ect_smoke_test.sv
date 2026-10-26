`ifndef DEBUG_ECT_SMOKE_TEST_SV
`define DEBUG_ECT_SMOKE_TEST_SV

// ==========================================
// Minimal AON ECT smoke test
// ==========================================
// Runs pulse and handshake sequences through the ECT agent:
//   sequence -> driver -> ect_aon_if -> monitor -> scoreboard
//
// The standalone debug-port top has no AON ECT DUT hookup yet.  This test
// validates the pulse and handshake paths.  It also checks monitor-to-
// scoreboard expectations using the injection-side CTI_AON event.  The test
// supplies the HiFi handshake ack only because the standalone top has no DUT
// connected yet.
// ==========================================

class debug_ect_smoke_test extends debug_port_base_test;
  `uvm_component_utils(debug_ect_smoke_test)

  function new(string name = "debug_ect_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void configure_env(debug_sys_cfg cfg);
    super.configure_env(cfg);
    cfg.enable_ect = 1'b1;
  endfunction

  virtual task main_phase(uvm_phase phase);
    ect_aon_pulse_sequence    pulse_seq;
    ect_aon_handshake_sequence handshake_seq;

    phase.raise_objection(this);

    if (env.vseqr == null || env.vseqr.ect_sequencer == null) begin
      `uvm_fatal("ECT_SMOKE", "AON ECT virtual sequencer path is not available")
    end

    // No DUT is connected in this standalone harness, so initialize the
    // HiFi ack low.  The test acts as the HiFi-side ack responder below.
    env.ect_cfg.vif.hifi_cti_out_ack = 1'b0;

    // Stage 1: pulse path and monitor -> scoreboard expectation check.
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN),
      .index(0),
      .expected_value(1'b1),
      .timeout_cycles(100)
    );

    pulse_seq = ect_aon_pulse_sequence::type_id::create("pulse_seq");
    if (!pulse_seq.randomize() with {
          loc          == ECT_AON_CTI_EVT_IN;
          index        == 0;
          value        == 1'b1;
          pulse_cycles == 1;
        }) begin
      `uvm_error("ECT_SMOKE", "Failed to randomize ECT pulse sequence")
    end

    pulse_seq.start(env.vseqr.ect_sequencer);

    // Keep one cycle after item_done so the monitor always samples the
    // deasserted pulse edge before the handshake stage begins.
    @(posedge env.ect_cfg.vif.clk);

    `uvm_info("ECT_SMOKE", "AON ECT pulse sequence completed", UVM_MEDIUM)

    // Stage 2: handshake path.  The driver waits for the mapped HiFi ack.
    env.ect_cfg.vif.hifi_cti_out_ack = 1'b0;
    env.ect_scoreboard.expect_event(
      .loc(ECT_AON_CTI_EVT_IN),
      .index(6),
      .expected_value(1'b1),
      .timeout_cycles(100)
    );

    handshake_seq = ect_aon_handshake_sequence::type_id::create(
      "handshake_seq");
    if (!handshake_seq.randomize() with {
          loc            == ECT_AON_CTI_EVT_IN;
          index          == 6;
          timeout_cycles == 100;
        }) begin
      `uvm_error("ECT_SMOKE", "Failed to randomize ECT handshake sequence")
    end

    fork
      begin
        handshake_seq.start(env.vseqr.ect_sequencer);
      end
      begin
        // Standalone HiFi ack responder: after the request is observed,
        // return ack one cycle later.  Clear ack after request deasserts.
        @(posedge env.ect_cfg.vif.clk);
        wait (env.ect_cfg.vif.cti_aon_evt_in[6] === 1'b1);
        @(posedge env.ect_cfg.vif.clk);
        env.ect_cfg.vif.hifi_cti_out_ack = 1'b1;
        wait (env.ect_cfg.vif.cti_aon_evt_in[6] !== 1'b1);
        env.ect_cfg.vif.hifi_cti_out_ack = 1'b0;
      end
    join

    `uvm_info("ECT_SMOKE", "AON ECT pulse and handshake sequences completed", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask
endclass

`endif
