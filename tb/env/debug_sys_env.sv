`ifndef DEBUG_SYS_ENV_SV
`define DEBUG_SYS_ENV_SV

class debug_sys_env extends uvm_env;
  debug_sys_cfg cfg;
  debug_sys_virtual_sequencer vseqr;
  debug_sys_scoreboard scoreboard;
  debug_sys_reg_block regmodel;

`ifdef DEBUG_PORT_JTAG
  svt_jtag_agent driver_agent;
  svt_jtag_agent controller_agent;
  svt_jtag_agent_configuration driver_cfg;
  svt_jtag_agent_configuration controller_cfg;
`elsif DEBUG_PORT_SWD
  svt_swd_master_agent master_agent;
  svt_swd_slave_agent slave_agent;
  svt_swd_agent_configuration master_cfg;
  svt_swd_agent_configuration slave_cfg;
`endif

  svt_apb_system_env apb_master_env;
  svt_apb_system_env apb_slave_env;
  svt_apb_system_configuration apb_master_cfg;
  svt_apb_system_configuration apb_slave_cfg;

  svt_axi_system_env axi_monitor_env;
  svt_axi_system_configuration axi_monitor_cfg;

  svt_atb_system_env atb_env;
  svt_atb_system_configuration atb_cfg;
  virtual svt_atb_if atb_vif;

  `uvm_component_utils(debug_sys_env)

  function new(string name = "debug_sys_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg))
      cfg = debug_sys_cfg::type_id::create("cfg");

    build_debug_port();
    if (cfg.enable_apb_ral) build_apb();
    if (cfg.enable_axi_monitor) build_axi_monitor();
    if (cfg.enable_atb) build_atb();

    scoreboard = debug_sys_scoreboard::type_id::create("scoreboard", this);
    vseqr = debug_sys_virtual_sequencer::type_id::create("vseqr", this);
  endfunction

  virtual function void build_debug_port();
`ifdef DEBUG_PORT_JTAG
    driver_cfg = new("driver_cfg");
    controller_cfg = new("controller_cfg");

    driver_cfg.is_active = 1;
    driver_cfg.mode_of_operation = svt_jtag_types::MODE_SYNCHRONOUS;
    driver_cfg.jtag_device_type = svt_jtag_types::JTAG_DRIVER;
    driver_cfg.inst_binary_for_device_identification_reg = 8'h06;

    controller_cfg.is_active = 1;
    controller_cfg.mode_of_operation = svt_jtag_types::MODE_SYNCHRONOUS;
    controller_cfg.jtag_device_type = svt_jtag_types::JTAG_CONTROLLER;
    controller_cfg.inst_binary_for_device_identification_reg = 8'h06;
    controller_cfg.data_width_for_device_identification_reg = 32;
    controller_cfg.initial_val_for_device_identification_reg = 32'hD06D_0001;

    uvm_config_db#(svt_jtag_agent_configuration)::set(
      this, "driver_agent", "cfg", driver_cfg);
    uvm_config_db#(svt_jtag_agent_configuration)::set(
      this, "controller_agent", "cfg", controller_cfg);
    uvm_config_db#(int)::set(this, "driver_agent*", "is_active", UVM_ACTIVE);
    uvm_config_db#(int)::set(this, "controller_agent*", "is_active", UVM_ACTIVE);

    driver_agent = svt_jtag_agent::type_id::create("driver_agent", this);
    controller_agent = svt_jtag_agent::type_id::create("controller_agent", this);
`elsif DEBUG_PORT_SWD
    master_cfg = new("master_cfg");
    slave_cfg = new("slave_cfg");

    master_cfg.is_active = 1;
    master_cfg.device_type = svt_swd_types::SWD_MASTER;
    master_cfg.WCR_turnaround_period = cfg.swd_turnaround;
    master_cfg.clock_period_ps = 10000;
    master_cfg.enable_get_response = 1;

    slave_cfg.is_active = 1;
    slave_cfg.device_type = svt_swd_types::SWD_SLAVE;
    slave_cfg.WCR_turnaround_period = cfg.swd_turnaround;
    slave_cfg.enable_get_response = 1;

    uvm_config_db#(svt_swd_agent_configuration)::set(
      this, "master_agent", "cfg", master_cfg);
    uvm_config_db#(svt_swd_agent_configuration)::set(
      this, "slave_agent", "cfg", slave_cfg);
    uvm_config_db#(int)::set(this, "master_agent*", "is_active", UVM_ACTIVE);
    uvm_config_db#(int)::set(this, "slave_agent*", "is_active", UVM_ACTIVE);

    master_agent = svt_swd_master_agent::type_id::create("master_agent", this);
    slave_agent = svt_swd_slave_agent::type_id::create("slave_agent", this);
`endif
  endfunction

  virtual function void build_apb();
    apb_master_cfg = new("apb_master_cfg");
    apb_slave_cfg = new("apb_slave_cfg");

    apb_master_cfg.paddr_width = svt_apb_system_configuration::PADDR_WIDTH_16;
    apb_master_cfg.pdata_width = svt_apb_system_configuration::PDATA_WIDTH_32;
    apb_master_cfg.create_sub_cfgs(1);
    apb_master_cfg.is_active = 1;
    apb_master_cfg.slave_cfg[0].is_active = 0;
    apb_master_cfg.uvm_reg_enable = 1;

    apb_slave_cfg.paddr_width = svt_apb_system_configuration::PADDR_WIDTH_16;
    apb_slave_cfg.pdata_width = svt_apb_system_configuration::PDATA_WIDTH_32;
    apb_slave_cfg.create_sub_cfgs(1);
    apb_slave_cfg.is_active = 0;
    apb_slave_cfg.slave_cfg[0].is_active = 1;

    uvm_config_db#(svt_apb_system_configuration)::set(
      this, "apb_master_env", "cfg", apb_master_cfg);
    uvm_config_db#(svt_apb_system_configuration)::set(
      this, "apb_slave_env", "cfg", apb_slave_cfg);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_master_env.master", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_master_env.slave[0]", "is_active", UVM_PASSIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_slave_env.master", "is_active", UVM_PASSIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_slave_env.slave[0]", "is_active", UVM_ACTIVE);

    regmodel = debug_sys_reg_block::type_id::create("regmodel");
    regmodel.build();
    regmodel.lock_model();
    uvm_config_db#(uvm_reg_block)::set(
      this, "apb_master_env.master", "apb_regmodel", regmodel);

    apb_master_env = svt_apb_system_env::type_id::create("apb_master_env", this);
    apb_slave_env = svt_apb_system_env::type_id::create("apb_slave_env", this);
  endfunction

  virtual function void build_axi_monitor();
    axi_monitor_cfg = new("axi_monitor_cfg");
    axi_monitor_cfg.num_masters = 1;
    axi_monitor_cfg.num_slaves = 1;
    axi_monitor_cfg.create_sub_cfgs(1, 1);
    axi_monitor_cfg.master_cfg[0].is_active = 0;
    axi_monitor_cfg.slave_cfg[0].is_active = 0;
    axi_monitor_cfg.master_cfg[0].data_width = cfg.axi_data_width;
    axi_monitor_cfg.slave_cfg[0].data_width = cfg.axi_data_width;
    axi_monitor_cfg.master_cfg[0].id_width = cfg.axi_id_width;
    axi_monitor_cfg.slave_cfg[0].id_width = cfg.axi_id_width;
    axi_monitor_cfg.master_cfg[0].protocol_checks_enable = cfg.enable_checks;
    axi_monitor_cfg.slave_cfg[0].protocol_checks_enable = cfg.enable_checks;
    axi_monitor_cfg.set_addr_range(0, 64'h0, 64'hffff_ffff_ffff_ffff);

    uvm_config_db#(svt_axi_system_configuration)::set(
      this, "axi_monitor_env", "cfg", axi_monitor_cfg);
    axi_monitor_env = svt_axi_system_env::type_id::create("axi_monitor_env", this);
  endfunction

  virtual function void build_atb();
    if (!uvm_config_db#(virtual svt_atb_if)::get(this, "", "atb_vif", atb_vif)) begin
      `uvm_fatal("NO_ATB_VIF", "ATB virtual interface was not configured")
    end

    atb_cfg = new("atb_cfg", atb_vif);
    atb_cfg.num_masters = 1;
    atb_cfg.num_slaves = 1;
    atb_cfg.create_sub_cfgs(1, 1);
    atb_cfg.master_cfg[0].is_active = 1;
    atb_cfg.slave_cfg[0].is_active = 1;
    atb_cfg.master_cfg[0].atb_port_kind = svt_atb_port_configuration::ATB_MASTER;
    atb_cfg.master_cfg[0].atb_interface_type = svt_atb_port_configuration::ATB1_1;
    atb_cfg.slave_cfg[0].atb_interface_type = svt_atb_port_configuration::ATB1_1;
    atb_cfg.master_cfg[0].data_width = 32;
    atb_cfg.slave_cfg[0].data_width = 32;
    atb_cfg.master_cfg[0].id_width = 7;
    atb_cfg.slave_cfg[0].id_width = 7;
    atb_cfg.slave_cfg[0].default_atready = 1;
    atb_cfg.master_cfg[0].flush_request_enable = 0;
    atb_cfg.slave_cfg[0].flush_request_enable = 0;
    atb_cfg.master_cfg[0].synchronization_enable = 0;
    atb_cfg.slave_cfg[0].synchronization_enable = 0;

    svt_config_object_db#(svt_atb_system_configuration)::set(
      this, "atb_env", "cfg", atb_cfg);
    atb_env = svt_atb_system_env::type_id::create("atb_env", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

`ifdef DEBUG_PORT_JTAG
    vseqr.port_sequencer = driver_agent.transaction_seqr;
    driver_agent.txrx_mon.rx_xact_observed_port.connect(scoreboard.debug_in);
    controller_agent.txrx_mon.rx_xact_observed_port.connect(scoreboard.debug_out);
`elsif DEBUG_PORT_SWD
    vseqr.port_sequencer = master_agent.transaction_seqr;
    master_agent.master_mon.rx_xact_observed_port.connect(scoreboard.debug_in);
    slave_agent.slave_mon.rx_xact_observed_port.connect(scoreboard.debug_out);
`endif

    if (cfg.enable_apb_ral) begin
      vseqr.apb_sequencer = apb_master_env.master.sequencer;
      vseqr.regmodel = regmodel;
      uvm_resource_db#(svt_apb_slave_agent)::set(
        "debug_sys_env", "apb_slave0", apb_slave_env.slave[0], this);
      apb_master_env.master.monitor.item_observed_port.connect(scoreboard.apb_in);
      apb_slave_env.slave[0].monitor.item_observed_port.connect(scoreboard.apb_out);
    end

    if (cfg.enable_axi_monitor) begin
      axi_monitor_env.master[0].monitor.item_observed_port.connect(scoreboard.axi_in);
      axi_monitor_env.slave[0].monitor.item_observed_port.connect(scoreboard.axi_out);
    end

    if (cfg.enable_atb) begin
      vseqr.atb_sequencer = atb_env.sequencer;
      atb_env.master[0].monitor.item_observed_port.connect(scoreboard.atb_in);
      atb_env.slave[0].monitor.item_observed_port.connect(scoreboard.atb_out);
    end
  endfunction
endclass

`endif
