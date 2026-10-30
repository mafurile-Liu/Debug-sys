`ifndef DEBUG_SYS_ENV_SV
`define DEBUG_SYS_ENV_SV

// ==========================================
// Debug System Top Environment
// ==========================================
// ?? env??????? env:
//
//   debug_sys_env (??)
//   |
//   +-- port_env     (JTAG + SWD ????, ?????? active)
//   |
//   +-- apb_env      (APB ??)
//   |
//   +-- atb_env      (ATB trace ??)
//   |
//   +-- scoreboard   (??: ??)
//   +-- coverage     (??: ???)
//   +-- vseqr        (??: ?? sequencer)
//
// ?????? plusarg: +debug_port_proto=JTAG ? +debug_port_proto=SWD
// ==========================================

class debug_sys_env extends uvm_env;

  // ????
  debug_sys_cfg cfg;
  debug_sys_virtual_sequencer vseqr;
  debug_sys_scoreboard scoreboard;
  debug_sys_coverage coverage;
  debug_sys_predictor predictor;

  // ??????? env
  debug_port_env port_env;   // JTAG + SWD (?????? active)
  debug_apb_env  apb_env;    // APB
  debug_atb_env  atb_env;    // ATB

  // AON ECT verification components.
  ect_aon_cfg        ect_cfg;
  ect_aon_agent      ect_agent;
  ect_aon_scoreboard ect_scoreboard;

  // ????? (? apb_env ??, ?? vseqr ??)
  debug_sys_reg_block regmodel;

  `uvm_component_utils(debug_sys_env)

  function new(string name = "debug_sys_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // ????
    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("ENV", "No cfg in config_db, created default", UVM_MEDIUM)
    end

    // ? cfg ????? env ? vseqr
    uvm_config_db#(debug_sys_cfg)::set(this, "port_env", "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "apb_env",  "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "atb_env",  "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "predictor", "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "vseqr",    "cfg", cfg);

    // ==========================================
    // ?????? env
    // ==========================================

    // Debug Port (JTAG + SWD) - ?????
    port_env = debug_port_env::type_id::create("port_env", this);
    `uvm_info("ENV", "debug_port_env created (JTAG+SWD agents)", UVM_MEDIUM)

    // APB
    if (cfg.enable_apb_ral) begin
      apb_env = debug_apb_env::type_id::create("apb_env", this);
      `uvm_info("ENV", "debug_apb_env created", UVM_MEDIUM)
    end

    // ATB
    if (cfg.enable_atb) begin
      atb_env = debug_atb_env::type_id::create("atb_env", this);
      `uvm_info("ENV", "debug_atb_env created", UVM_MEDIUM)
    end

    // AON ECT agent/scoreboard
    if (cfg.enable_ect) begin
      ect_cfg       = ect_aon_cfg::type_id::create("ect_cfg");

      if (!uvm_config_db#(virtual ect_aon_if)::get(this, "", "ect_vif", ect_cfg.vif)) begin
        `uvm_fatal("ENV", "AON ECT interface not found in config_db")
      end

      ect_agent      = ect_aon_agent::type_id::create("ect_agent", this);
      ect_scoreboard = ect_aon_scoreboard::type_id::create("ect_scoreboard", this);

      uvm_config_db#(ect_aon_cfg)::set(this, "ect_agent", "cfg", ect_cfg);
      uvm_config_db#(ect_aon_cfg)::set(this, "ect_scoreboard", "cfg", ect_cfg);
      `uvm_info("ENV", "AON ECT agent/scoreboard created", UVM_MEDIUM)
    end

    // ==========================================
    // ??????
    // ==========================================
    scoreboard = debug_sys_scoreboard::type_id::create("scoreboard", this);

    if (cfg.enable_predictor) begin
      predictor = debug_sys_predictor::type_id::create("predictor", this);
    end

    if (cfg.enable_coverage) begin
      coverage = debug_sys_coverage::type_id::create("coverage", this);
    end

    vseqr = debug_sys_virtual_sequencer::type_id::create("vseqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // ==========================================
    // 1. ?? sequencer ?????? sequencer
    // ==========================================

    // Debug Port: JTAG ? SWD ???
    vseqr.jtag_sequencer = port_env.jtag_driver_agent.transaction_seqr;
    vseqr.swd_sequencer  = port_env.swd_master_agent.transaction_seqr;

    // APB sequencer + regmodel
    if (cfg.enable_apb_ral && apb_env != null) begin
      vseqr.apb_sequencer = apb_env.get_master_sequencer();
      vseqr.regmodel      = apb_env.regmodel;
      regmodel            = apb_env.regmodel;

      // ??????? resource
      uvm_resource_db#(svt_apb_slave_agent)::set(
        "debug_sys_env", "apb_slave0", apb_env.get_slave_agent(0), this);
    end

    // ATB sequencer
    if (cfg.enable_atb && atb_env != null) begin
      vseqr.atb_sequencer = atb_env.get_sequencer();
    end

    `uvm_info("ENV", $sformatf("Active debug port protocol: %s",
      cfg.port_protocol.name()), UVM_MEDIUM)

    // ==========================================
    // 2. Scoreboard ?? (Master->exp, Slave->actual)
    // ==========================================

    // APB scoreboard ??
    if (cfg.enable_apb_ral && apb_env != null) begin
      if (cfg.enable_predictor && predictor != null) begin
        apb_env.apb_master_env.master.monitor.item_observed_port.connect(
          predictor.apb_in);
        predictor.apb_exp.connect(scoreboard.apb_exp);
      end else begin
        apb_env.apb_master_env.master.monitor.item_observed_port.connect(
          scoreboard.apb_exp);
      end
      apb_env.apb_slave_env.slave[0].monitor.item_observed_port.connect(
        scoreboard.apb_actual);
      `uvm_info("ENV", "APB monitors connected to scoreboard", UVM_MEDIUM)
    end

    // ATB scoreboard ??
    if (cfg.enable_atb && atb_env != null) begin
      if (cfg.enable_predictor && predictor != null) begin
        atb_env.atb_env.master[0].monitor.item_observed_port.connect(
          predictor.atb_in);
        predictor.atb_exp.connect(scoreboard.atb_exp);
      end else begin
        atb_env.atb_env.master[0].monitor.item_observed_port.connect(
          scoreboard.atb_exp);
      end
      atb_env.atb_env.slave[0].monitor.item_observed_port.connect(
        scoreboard.atb_actual);
      `uvm_info("ENV", "ATB monitors connected to scoreboard", UVM_MEDIUM)
    end

    // AON ECT monitor -> scoreboard
    if (cfg.enable_ect && ect_agent != null && ect_scoreboard != null) begin
      ect_agent.monitor.ap.connect(ect_scoreboard.analysis_export);
      `uvm_info("ENV", "AON ECT monitor connected to scoreboard", UVM_MEDIUM)
    end

    // Expose the ECT sequencer to virtual sequences.
    if (cfg.enable_ect && ect_agent != null) begin
      vseqr.ect_sequencer = ect_agent.sequencer;
    end

    // ==========================================
    // 3. Coverage ??
    // ==========================================
    if (cfg.enable_coverage && coverage != null) begin
      if (cfg.enable_apb_ral && apb_env != null) begin
        apb_env.apb_master_env.master.monitor.item_observed_port.connect(
          coverage.apb_export);
        `uvm_info("ENV", "APB coverage connected", UVM_MEDIUM)
      end
    end

    `uvm_info("ENV", "Environment connect phase complete", UVM_MEDIUM)
  endfunction

endclass

`endif
