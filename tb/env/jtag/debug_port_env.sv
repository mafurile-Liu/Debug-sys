`ifndef DEBUG_PORT_ENV_SV
`define DEBUG_PORT_ENV_SV

// ==========================================
// Debug Port Environment (JTAG + SWD)
// ==========================================
// 同时支持 JTAG 和 SWD 两种协议, 运行时通过 plusarg 选择:
//   +debug_port_proto=JTAG  (默认)
//   +debug_port_proto=SWD
//
// 重要: is_active 必须在 agent create 之前设置到 config_db,
//      否则 VIP build_phase 已经按 ACTIVE 创建了 driver, 再改就晚了!
//
// 对外提供的 sequencer:
//   get_port_sequencer() - 返回当前激活协议的 sequencer
// ==========================================

class debug_port_env extends uvm_env;

  // 配置
  debug_sys_cfg cfg;

  // JTAG agent
  cust_jtag_cfg jtag_driver_cfg_obj;
  cust_jtag_cfg jtag_controller_cfg_obj;
  svt_jtag_agent jtag_driver_agent;
  svt_jtag_agent jtag_controller_agent;

  // SWD agent
  cust_swd_master_cfg swd_master_cfg_obj;
  cust_swd_slave_cfg  swd_slave_cfg_obj;
  svt_swd_master_agent swd_master_agent;
  svt_swd_slave_agent  swd_slave_agent;

  `uvm_component_utils(debug_port_env)

  function new(string name = "debug_port_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("PORT_ENV", "No cfg in config_db, created default", UVM_MEDIUM)
    end

    // ==========================================
    // 关键: 在 create agent 之前, 先把 is_active 放入 config_db!
    // 否则 VIP build_phase 已经按 ACTIVE 创建了 driver/monitor, 再改就晚了!
    // 不激活的协议设为 UVM_PASSIVE, 这样 VIP 不会 build driver, 不会去 drive interface
    // ==========================================
    if (cfg.is_jtag()) begin
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "jtag_driver_agent", "is_active", UVM_ACTIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "jtag_controller_agent", "is_active", UVM_ACTIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "swd_master_agent", "is_active", UVM_PASSIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "swd_slave_agent", "is_active", UVM_PASSIVE);
    end else begin
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "jtag_driver_agent", "is_active", UVM_PASSIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "jtag_controller_agent", "is_active", UVM_PASSIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "swd_master_agent", "is_active", UVM_ACTIVE);
      uvm_config_db#(uvm_active_passive_enum)::set(
        this, "swd_slave_agent", "is_active", UVM_ACTIVE);
    end

    // ==========================================
    // 配置对象也要先放 config_db, 再 create agent
    // ==========================================
    build_jtag_config();
    build_swd_config();

    // ==========================================
    // 现在 create agent (此时 config_db 里已经有 is_active 了)
    // ==========================================
    jtag_driver_agent     = svt_jtag_agent::type_id::create("jtag_driver_agent", this);
    jtag_controller_agent = svt_jtag_agent::type_id::create("jtag_controller_agent", this);
    swd_master_agent      = svt_swd_master_agent::type_id::create("swd_master_agent", this);
    swd_slave_agent       = svt_swd_slave_agent::type_id::create("swd_slave_agent", this);

    `uvm_info("PORT_ENV", $sformatf(
      "Agents built. Active protocol: %s (JTAG=%s, SWD=%s)",
      cfg.port_protocol.name(),
      cfg.is_jtag() ? "ACTIVE" : "PASSIVE",
      cfg.is_swd()  ? "ACTIVE" : "PASSIVE"), UVM_MEDIUM)
  endfunction

  // ==========================================
  // 构建 JTAG 配置 (只创建 cfg 对象, 放到 config_db)
  // ==========================================
  virtual function void build_jtag_config();
    // Master 端配置
    jtag_driver_cfg_obj = cust_jtag_cfg::type_id::create("jtag_driver_cfg_obj");
    uvm_config_db#(svt_jtag_agent_configuration)::set(
      this, "jtag_driver_agent", "cfg", jtag_driver_cfg_obj);

    // Controller/Slave 端配置
    jtag_controller_cfg_obj = cust_jtag_cfg::type_id::create("jtag_controller_cfg_obj");
    jtag_controller_cfg_obj.jtag_device_type = svt_jtag_types::JTAG_CONTROLLER;
    jtag_controller_cfg_obj.data_width_for_device_identification_reg = 32;
    jtag_controller_cfg_obj.initial_val_for_device_identification_reg = 32'hD06D0001;
    uvm_config_db#(svt_jtag_agent_configuration)::set(
      this, "jtag_controller_agent", "cfg", jtag_controller_cfg_obj);
  endfunction

  // ==========================================
  // 构建 SWD 配置 (只创建 cfg 对象, 放到 config_db)
  // ==========================================
  virtual function void build_swd_config();
    // Master 端配置
    swd_master_cfg_obj = cust_swd_master_cfg::type_id::create("swd_master_cfg_obj");
    uvm_config_db#(svt_swd_agent_configuration)::set(
      this, "swd_master_agent", "cfg", swd_master_cfg_obj);

    // Slave 端配置
    swd_slave_cfg_obj = cust_swd_slave_cfg::type_id::create("swd_slave_cfg_obj");
    uvm_config_db#(svt_swd_agent_configuration)::set(
      this, "swd_slave_agent", "cfg", swd_slave_cfg_obj);
  endfunction

  // ==========================================
  // 获取当前激活协议的 sequencer
  // ==========================================
  virtual function uvm_sequencer_base get_port_sequencer();
    if (cfg.is_jtag()) begin
      get_port_sequencer = jtag_driver_agent.transaction_seqr;
    end else begin
      get_port_sequencer = swd_master_agent.transaction_seqr;
    end
  endfunction

endclass

`endif
