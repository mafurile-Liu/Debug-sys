`ifndef DEBUG_SYS_ENV_SV
`define DEBUG_SYS_ENV_SV

// ==========================================
// Debug System Environment
// ==========================================
// Configuration Hierarchy:
//   test -> configure_env() -> debug_sys_cfg
//                              -> create cust_*_cfg for each VIP
//                              -> pass via config_db
//
// No hierarchical references - 100% config_db based
// ==========================================

class debug_sys_env extends uvm_env;
  debug_sys_cfg cfg;
  debug_sys_virtual_sequencer vseqr;
  debug_sys_scoreboard scoreboard;
  debug_sys_predictor predictor;
  debug_sys_reg_block regmodel;

  // Custom VIP configurations (project-specific)
  cust_apb_cfg apb_master_cfg_obj;
  cust_apb_cfg apb_slave_cfg_obj;
  cust_axi_monitor_cfg axi_monitor_cfg_obj;
  cust_atb_cfg atb_cfg_obj;
`ifdef DEBUG_PORT_JTAG
  cust_jtag_cfg driver_cfg_obj;
  cust_jtag_cfg controller_cfg_obj;
`elsif DEBUG_PORT_SWD
  cust_swd_master_cfg master_cfg_obj;
  cust_swd_slave_cfg slave_cfg_obj;
`endif

  `uvm_component_utils(debug_sys_env)

  function new(string name = "debug_sys_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration from config_db (set by test in build_phase)
    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_info("ENV", "No cfg in config_db, creating default", UVM_MEDIUM)
      cfg = debug_sys_cfg::type_id::create("cfg");
    end

    // Build debug port using custom configuration classes
    build_debug_port();

    // Build APB using cust_apb_cfg
    if (cfg.enable_apb_ral) build_apb();

    // Build AXI monitor using cust_axi_monitor_cfg
    if (cfg.enable_axi_monitor) build_axi_monitor();

    // Build ATB using cust_atb_cfg
    if (cfg.enable_atb) build_atb();

    // Scoreboard and Coverage (separate - SRP)
    scoreboard = debug_sys_scoreboard::type_id::create("scoreboard", this);
    vseqr      = debug_sys_virtual_sequencer::type_id::create("vseqr", this);

    // Predictor: predicts expected exit-port transactions from the addr map.
    predictor = debug_sys_predictor::type_id::create("predictor", this);
    predictor.map = cfg.addr_map;
    predictor.cfg = cfg;
  endfunction

  virtual function void build_debug_port();
`ifdef DEBUG_PORT_JTAG
    // Use project-specific JTAG config
    driver_cfg_obj = cust_jtag_cfg::type_id::create("driver_cfg_obj");
    controller_cfg_obj = cust_jtag_cfg::type_id::create("controller_cfg_obj");

    // Override for controller (slave) side
    controller_cfg_obj.jtag_device_type = svt_jtag_types::JTAG_CONTROLLER;
    controller_cfg_obj.data_width_for_device_identification_reg = 32;
    controller_cfg_obj.initial_val_for_device_identification_reg = 32'hD06D0001;

    uvm_config_db#(svt_jtag_agent_configuration)::set(this, "driver_agent", "cfg", driver_cfg_obj);
    uvm_config_db#(svt_jtag_agent_configuration)::set(this, "controller_agent", "cfg", controller_cfg_obj);

    driver_agent = svt_jtag_agent::type_id::create("driver_agent", this);
    controller_agent = svt_jtag_agent::type_id::create("controller_agent", this);
`elsif DEBUG_PORT_SWD
    // Use project-specific SWD config
    master_cfg_obj = cust_swd_master_cfg::type_id::create("master_cfg_obj");
    slave_cfg_obj = cust_swd_slave_cfg::type_id::create("slave_cfg_obj");

    uvm_config_db#(svt_swd_agent_configuration)::set(this, "master_agent", "cfg", master_cfg_obj);
    uvm_config_db#(svt_swd_agent_configuration)::set(this, "slave_agent", "cfg", slave_cfg_obj);

    master_agent = svt_swd_master_agent::type_id::create("master_agent", this);
    slave_agent = svt_swd_slave_agent::type_id::create("slave_agent", this);
`endif
  endfunction

  virtual function void build_apb();
    // Use project-specific APB config
    apb_master_cfg_obj = cust_apb_cfg::type_id::create("apb_master_cfg_obj");
    apb_slave_cfg_obj = cust_apb_cfg::type_id::create("apb_slave_cfg_obj");

    // Master side setup
    apb_master_cfg_obj.is_active = 1'b1;
    apb_master_cfg_obj.slave_cfg[0].is_active = 1'b0;

    // Slave side setup
    apb_slave_cfg_obj.is_active = 1'b0;
    apb_slave_cfg_obj.slave_cfg[0].is_active = 1'b1;

    // Pass VIP configs via config_db
    uvm_config_db#(svt_apb_system_configuration)::set(this, "apb_master_env", "cfg", apb_master_cfg_obj);
    uvm_config_db#(svt_apb_system_configuration)::set(this, "apb_slave_env", "cfg", apb_slave_cfg_obj);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_master_env.master", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_master_env.slave[0]", "is_active", UVM_PASSIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_slave_env.master", "is_active", UVM_PASSIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_slave_env.slave[0]", "is_active", UVM_ACTIVE);

    // Create and connect RAL model
    regmodel = debug_sys_reg_block::type_id::create("regmodel");
    regmodel.build();
    regmodel.lock_model();
    uvm_config_db#(uvm_reg_block)::set(this, "apb_master_env.master", "apb_regmodel", regmodel);

    apb_master_env = svt_apb_system_env::type_id::create("apb_master_env", this);
    apb_slave_env = svt_apb_system_env::type_id::create("apb_slave_env", this);
  endfunction

  virtual function void build_axi_monitor();
    axi_monitor_cfg_obj = cust_axi_monitor_cfg::type_id::create("axi_monitor_cfg_obj");
    uvm_config_db#(svt_axi_system_configuration)::set(this, "axi_monitor_env", "cfg", axi_monitor_cfg_obj);
    axi_monitor_env = svt_axi_system_env::type_id::create("axi_monitor_env", this);
  endfunction

  virtual function void build_atb();
    virtual svt_atb_if atb_vif;
    if (!uvm_config_db#(virtual svt_atb_if)::get(this, "", "atb_vif", atb_vif)) begin
      `uvm_fatal("NO_ATB_VIF", "ATB interface not found in config_db")
    end

    atb_cfg_obj = cust_atb_cfg::type_id::create("atb_cfg_obj");
    atb_cfg_obj.vif = atb_vif;  // Pass interface to config constructor

    svt_config_object_db#(svt_atb_system_configuration)::set(this, "atb_env", "cfg", atb_cfg_obj);
    atb_env = svt_atb_system_env::type_id::create("atb_env", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Flow: in-monitor -> predictor -> scoreboard(expected);
    //      out-monitor -> scoreboard(actual).
`ifdef DEBUG_PORT_JTAG
    vseqr.port_sequencer = driver_agent.transaction_seqr;
    driver_agent.txrx_mon.rx_xact_observed_port.connect(predictor.debug_in);
    controller_agent.txrx_mon.rx_xact_observed_port.connect(scoreboard.debug_actual);
`elsif DEBUG_PORT_SWD
    vseqr.port_sequencer = master_agent.transaction_seqr;
    master_agent.master_mon.rx_xact_observed_port.connect(predictor.debug_in);
    slave_agent.slave_mon.rx_xact_observed_port.connect(scoreboard.debug_actual);
`endif
    predictor.debug_exp.connect(scoreboard.debug_exp);

    if (cfg.enable_apb_ral) begin
      vseqr.apb_sequencer = apb_master_env.master.sequencer;
      vseqr.regmodel = regmodel;
      uvm_resource_db#(svt_apb_slave_agent)::set(
        "debug_sys_env", "apb_slave0", apb_slave_env.slave[0], this);
      apb_master_env.master.monitor.item_observed_port.connect(predictor.apb_in);
      apb_slave_env.slave[0].monitor.item_observed_port.connect(scoreboard.apb_actual);
    end
    predictor.apb_exp.connect(scoreboard.apb_exp);

    if (cfg.enable_axi_monitor) begin
      axi_monitor_env.master[0].monitor.item_observed_port.connect(predictor.axi_in);
      axi_monitor_env.slave[0].monitor.item_observed_port.connect(scoreboard.axi_actual);
    end
    predictor.axi_exp.connect(scoreboard.axi_exp);

    if (cfg.enable_atb) begin
      vseqr.atb_sequencer = atb_env.sequencer;
      atb_env.master[0].monitor.item_observed_port.connect(predictor.atb_in);
      atb_env.slave[0].monitor.item_observed_port.connect(scoreboard.atb_actual);
    end
    predictor.atb_exp.connect(scoreboard.atb_exp);
  endfunction

endclass

`endif