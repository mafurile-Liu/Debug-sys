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
    ect_aon_pulse_sequence pulse_seq;
    ect_aon_all_handshake_pairs_sequence handshake_seq;
    ect_aon_loc_e req_loc[5];
    int unsigned req_idx[5];
    ect_aon_loc_e ack_loc[5];

    req_loc = '{
      ECT_AON_CTI_EVT_IN,
      ECT_AON_CTI_EVT_IN,
      ECT_AON_CTI_EVT_OUT,
      ECT_AON_CTI_EVT_OUT,
      ECT_AON_CTI_EVT_OUT
    };
    req_idx = '{6, 7, 7, 8, 14};
    ack_loc = '{
      ECT_AON_ACK_HIFI_CTI_OUT,
      ECT_AON_ACK_HIFI_BREAK_OUT,
      ECT_AON_ACK_HIFI_CTI_IN,
      ECT_AON_ACK_HIFI_BREAK_IN,
      ECT_AON_ACK_TBU
    };

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

    // Stage 2: run all mapped handshake request/ack paths.  The standalone
    // top has no DUT, so the test maps each request to its ack one cycle
    // later.
    foreach (req_loc[i]) begin
      env.ect_scoreboard.expect_event(
        .loc(req_loc[i]), .index(req_idx[i]),
        .expected_value(1'b1), .timeout_cycles(100)
      );
      env.ect_scoreboard.expect_event(
        .loc(ack_loc[i]), .index(0),
        .expected_value(1'b1), .timeout_cycles(100)
      );
      env.ect_scoreboard.expect_event(
        .loc(req_loc[i]), .index(req_idx[i]),
        .expected_value(1'b0), .timeout_cycles(100)
      );
      env.ect_scoreboard.expect_event(
        .loc(ack_loc[i]), .index(0),
        .expected_value(1'b0), .timeout_cycles(100)
      );
    end

    handshake_seq = ect_aon_all_handshake_pairs_sequence::type_id::create(
      "handshake_seq");
    if (!handshake_seq.randomize() with {
          timeout_cycles == 100;
        }) begin
      `uvm_error("ECT_SMOKE", "Failed to randomize ECT all-pair handshake sequence")
    end

    fork
      begin
        handshake_seq.start(env.vseqr.ect_sequencer);
      end
      begin
        // Standalone ack responder: register each request and update the
        // mapped ack with nonblocking assignments.  This gives a one-cycle
        // response and avoids same-edge sampling races with the driver and
        // monitor.
        forever begin
          @(posedge env.ect_cfg.vif.clk);
          env.ect_cfg.vif.hifi_cti_out_ack <=
            env.ect_cfg.vif.cti_aon_evt_in[6];
          env.ect_cfg.vif.hifi_break_out_ack <=
            env.ect_cfg.vif.cti_aon_evt_in[7];
          env.ect_cfg.vif.hifi_cti_in_ack <=
            env.ect_cfg.vif.cti_aon_evt_out[7];
          env.ect_cfg.vif.hifi_break_in_ack <=
            env.ect_cfg.vif.cti_aon_evt_out[8];
          env.ect_cfg.vif.tbu_pmusnapshot_ack <=
            env.ect_cfg.vif.cti_aon_evt_out[14];
        end
      end
    join_any

    // Allow the final ack-low NBA and monitor sample to complete before
    // stopping the standalone responder.
    @(posedge env.ect_cfg.vif.clk);
    disable fork;

    `uvm_info("ECT_SMOKE", "AON ECT pulse and handshake sequences completed", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask
endclass

`endif
