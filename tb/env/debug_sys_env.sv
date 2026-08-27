`ifndef DEBUG_SYS_ENV_SV
`define DEBUG_SYS_ENV_SV

// ==========================================
// Debug System Top Environment
// ==========================================
// 顶层 env，按协议拆分子 env:
//
//   debug_sys_env (顶层)
//   |
//   +-- port_env     (JTAG + SWD 调试端口, 运行时选一个 active)
//   |
//   +-- apb_env      (APB 总线)
//   |
//   +-- atb_env      (ATB trace 总线)
//   |
//   +-- scoreboard   (公共: 比对)
//   +-- coverage     (公共: 覆盖率)
//   +-- vseqr        (公共: 虚拟 sequencer)
//
// 协议选择通过 plusarg: +debug_port_proto=JTAG 或 +debug_port_proto=SWD
// ==========================================

class debug_sys_env extends uvm_env;

  // 公共组件
  debug_sys_cfg cfg;
  debug_sys_virtual_sequencer vseqr;
  debug_sys_scoreboard scoreboard;
  debug_sys_coverage coverage;
  debug_sys_predictor predictor;

  // 按协议拆分的子 env
  debug_port_env port_env;   // JTAG + SWD (运行时二选一 active)
  debug_apb_env  apb_env;    // APB
  debug_atb_env  atb_env;    // ATB

  // 寄存器模型 (从 apb_env 引出, 方便 vseqr 使用)
  debug_sys_reg_block regmodel;

  `uvm_component_utils(debug_sys_env)

  function new(string name = "debug_sys_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 获取配置
    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("ENV", "No cfg in config_db, created default", UVM_MEDIUM)
    end

    // 把 cfg 传给所有子 env 和 vseqr
    uvm_config_db#(debug_sys_cfg)::set(this, "port_env", "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "apb_env",  "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "atb_env",  "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "predictor", "cfg", cfg);
    uvm_config_db#(debug_sys_cfg)::set(this, "vseqr",    "cfg", cfg);

    // ==========================================
    // 构建各协议子 env
    // ==========================================

    // Debug Port (JTAG + SWD) - 始终都例化
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

    // ==========================================
    // 构建公共组件
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
    // 1. 虚拟 sequencer 连接到各协议 sequencer
    // ==========================================

    // Debug Port: JTAG 和 SWD 都连上
    vseqr.jtag_sequencer = port_env.jtag_driver_agent.transaction_seqr;
    vseqr.swd_sequencer  = port_env.swd_master_agent.transaction_seqr;

    // APB sequencer + regmodel
    if (cfg.enable_apb_ral && apb_env != null) begin
      vseqr.apb_sequencer = apb_env.get_master_sequencer();
      vseqr.regmodel      = apb_env.regmodel;
      regmodel            = apb_env.regmodel;

      // 给其他组件用的 resource
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
    // 2. Scoreboard 连接 (Master->exp, Slave->actual)
    // ==========================================

    // APB scoreboard 连接
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

    // ATB scoreboard 连接
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

    // ==========================================
    // 3. Coverage 连接
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
