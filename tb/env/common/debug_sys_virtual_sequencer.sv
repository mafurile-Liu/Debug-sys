`ifndef DEBUG_SYS_VIRTUAL_SEQUENCER_SV
`define DEBUG_SYS_VIRTUAL_SEQUENCER_SV

// ==========================================
// Debug System Virtual Sequencer
// ==========================================
// 同时持有 JTAG 和 SWD sequencer 句柄
// 运行时根据 cfg.port_protocol 决定使用哪一个
//
// 使用方式:
//   JTAG 序列 -> vseqr.jtag_sequencer
//   SWD 序列  -> vseqr.swd_sequencer
// ==========================================

class debug_sys_virtual_sequencer extends
  uvm_sequencer#(uvm_sequence_item, uvm_sequence_item);

  typedef virtual debug_reset_if.seq_mp reset_vif_t;
  reset_vif_t reset_vif;

  // 配置
  debug_sys_cfg cfg;

  // Debug port sequencers (JTAG 和 SWD 都有)
  svt_jtag_transaction_sequencer jtag_sequencer;
  svt_swd_transaction_sequencer  swd_sequencer;

  // 其他协议 sequencer
  svt_apb_master_sequencer apb_sequencer;
  svt_atb_system_sequencer atb_sequencer;
  debug_sys_reg_block regmodel;

  `uvm_component_utils(debug_sys_virtual_sequencer)

  function new(string name = "debug_sys_virtual_sequencer",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
    end

    if (!uvm_config_db#(reset_vif_t)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NO_RESET_VIF", "debug_reset_if.seq_mp was not configured")
    end
  endfunction

  // ==========================================
  // 便捷方法: 获取当前激活协议的 sequencer (基类类型)
  // ==========================================
  virtual function uvm_sequencer_base get_active_port_sequencer();
    if (cfg.is_jtag()) begin
      get_active_port_sequencer = jtag_sequencer;
    end else begin
      get_active_port_sequencer = swd_sequencer;
    end
  endfunction

endclass

`endif
