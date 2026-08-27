`ifndef DEBUG_ATB_ENV_SV
`define DEBUG_ATB_ENV_SV

// ==========================================
// ATB Environment
// ==========================================
// 封装 CoreSight ATB (Advanced Trace Bus) VIP
//
// 对外提供的 sequencer:
//   atb_sequencer - 用于发送 ATB trace 事务
//
// 对外提供的 monitor port:
//   master_monitor_port - Master 端观测端口 (接 scoreboard exp)
//   slave_monitor_port  - Slave 端观测端口 (接 scoreboard actual)
// ==========================================

class debug_atb_env extends uvm_env;

  // 配置
  debug_sys_cfg cfg;

  // 配置对象
  cust_atb_cfg atb_cfg_obj;

  // VIP System Env
  svt_atb_system_env atb_env;

  `uvm_component_utils(debug_atb_env)

  function new(string name = "debug_atb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("ATB_ENV", "No cfg in config_db, created default", UVM_MEDIUM)
    end

    if (cfg.enable_atb) begin
      build_atb_agents();
    end
  endfunction

  // ==========================================
  // 构建 ATB agent
  // ==========================================
  virtual function void build_atb_agents();
    virtual svt_atb_if atb_vif;

    // 从 config_db 获取 ATB 接口
    if (!uvm_config_db#(virtual svt_atb_if)::get(this, "", "atb_vif", atb_vif)) begin
      `uvm_fatal("NO_ATB_VIF", "ATB interface not found in config_db")
    end

    // 配置
    atb_cfg_obj = cust_atb_cfg::type_id::create("atb_cfg_obj");
    atb_cfg_obj.vif = atb_vif;
    svt_config_object_db#(svt_atb_system_configuration)::set(
      this, "atb_env", "cfg", atb_cfg_obj);

    // 实例化
    atb_env = svt_atb_system_env::type_id::create("atb_env", this);

    `uvm_info("ATB_ENV", "ATB system env built", UVM_MEDIUM)
  endfunction

  // ==========================================
  // 便捷方法: 获取 sequencer
  // ==========================================
  virtual function svt_atb_system_sequencer get_sequencer();
    get_sequencer = atb_env.sequencer;
  endfunction

endclass

`endif
