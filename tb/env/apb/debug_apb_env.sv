`ifndef DEBUG_APB_ENV_SV
`define DEBUG_APB_ENV_SV

// ==========================================
// APB Environment
// ==========================================
// 封装 APB Master/Slave VIP 和 RAL 寄存器模型
//
// 对外提供的 sequencer:
//   master_sequencer - 用于发送 APB 事务
//
// 对外提供的 monitor port:
//   master_monitor_port  - Master 端观测端口 (接 scoreboard exp)
//   slave_monitor_port   - Slave 端观测端口 (接 scoreboard actual)
// ==========================================

class debug_apb_env extends uvm_env;

  // 配置
  debug_sys_cfg cfg;

  // 配置对象
  cust_apb_cfg apb_master_cfg_obj;
  cust_apb_cfg apb_slave_cfg_obj;

  // VIP System Env
  svt_apb_system_env apb_master_env;
  svt_apb_system_env apb_slave_env;

  // 寄存器模型
  debug_sys_reg_block regmodel;

  `uvm_component_utils(debug_apb_env)

  function new(string name = "debug_apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("APB_ENV", "No cfg in config_db, created default", UVM_MEDIUM)
    end

    if (cfg.enable_apb_ral) begin
      build_apb_agents();
      build_regmodel();
    end
  endfunction

  // ==========================================
  // 构建 APB Master/Slave agent
  // ==========================================
  virtual function void build_apb_agents();
    // Master 配置
    apb_master_cfg_obj = cust_apb_cfg::type_id::create("apb_master_cfg_obj");
    apb_master_cfg_obj.is_active = 1'b1;
    apb_master_cfg_obj.slave_cfg[0].is_active = 1'b0;
    uvm_config_db#(svt_apb_system_configuration)::set(
      this, "apb_master_env", "cfg", apb_master_cfg_obj);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_master_env.master", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_master_env.slave[0]", "is_active", UVM_PASSIVE);

    // Slave 配置
    apb_slave_cfg_obj = cust_apb_cfg::type_id::create("apb_slave_cfg_obj");
    apb_slave_cfg_obj.is_active = 1'b0;
    apb_slave_cfg_obj.slave_cfg[0].is_active = 1'b1;
    uvm_config_db#(svt_apb_system_configuration)::set(
      this, "apb_slave_env", "cfg", apb_slave_cfg_obj);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_slave_env.master", "is_active", UVM_PASSIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(
      this, "apb_slave_env.slave[0]", "is_active", UVM_ACTIVE);

    // 实例化
    apb_master_env = svt_apb_system_env::type_id::create("apb_master_env", this);
    apb_slave_env  = svt_apb_system_env::type_id::create("apb_slave_env", this);

    `uvm_info("APB_ENV", "APB master/slave agents built", UVM_MEDIUM)
  endfunction

  // ==========================================
  // 构建寄存器模型
  // ==========================================
  virtual function void build_regmodel();
    regmodel = debug_sys_reg_block::type_id::create("regmodel");
    regmodel.build();
    regmodel.lock_model();
    uvm_config_db#(uvm_reg_block)::set(
      this, "apb_master_env.master", "apb_regmodel", regmodel);
    `uvm_info("APB_ENV", "Register model built", UVM_MEDIUM)
  endfunction

  // ==========================================
  // 便捷方法: 获取 master sequencer
  // ==========================================
  virtual function svt_apb_master_sequencer get_master_sequencer();
    get_master_sequencer = apb_master_env.master.sequencer;
  endfunction

  // ==========================================
  // 便捷方法: 获取 slave agent
  // ==========================================
  virtual function svt_apb_slave_agent get_slave_agent(int idx = 0);
    get_slave_agent = apb_slave_env.slave[idx];
  endfunction

endclass

`endif
