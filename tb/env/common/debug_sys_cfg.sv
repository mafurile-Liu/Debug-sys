`ifndef DEBUG_SYS_CFG_SV
`define DEBUG_SYS_CFG_SV

// ==========================================
// Debug System Configuration
// ==========================================
// 运行时配置对象, 通过 plusarg 控制协议选择
//
// 协议选择:
//   +debug_port_proto=JTAG  -> 使用 JTAG 协议
//   +debug_port_proto=SWD   -> 使用 SWD 协议
// ==========================================

typedef enum {
  PROTO_JTAG,  // JTAG 协议
  PROTO_SWD    // SWD 协议
} debug_proto_e;

class debug_sys_cfg extends uvm_object;
  // AXI is intentionally unconnected in standalone mode; enable after DUT hookup.
  bit          enable_checks     = 1'b0;
  bit          enable_coverage   = 1'b1;
  bit          enable_apb_ral     = 1'b1;
  bit          enable_axi_monitor = 1'b1;
  bit          enable_atb        = 1'b1;
  bit          enable_predictor  = 1'b1; // route through predictor/scoreboard
  int unsigned swd_turnaround    = 1;
  int unsigned axi_data_width    = 32;
  int unsigned axi_id_width      = 4;

  // 调试端口协议选择 (运行时通过 plusarg 设置)
  debug_proto_e port_protocol = PROTO_JTAG;  // 默认 JTAG

  // Address-routing model. Default = standalone identity map; tests/DUT replace it.
  debug_sys_addr_map addr_map;

  `uvm_object_utils_begin(debug_sys_cfg)
    `uvm_field_enum(debug_proto_e, port_protocol, UVM_DEFAULT)
    `uvm_field_int(enable_checks, UVM_DEFAULT)
    `uvm_field_int(enable_coverage, UVM_DEFAULT)
    `uvm_field_int(enable_apb_ral, UVM_DEFAULT)
    `uvm_field_int(enable_axi_monitor, UVM_DEFAULT)
    `uvm_field_int(enable_atb, UVM_DEFAULT)
    `uvm_field_int(enable_predictor, UVM_DEFAULT)
    `uvm_field_int(swd_turnaround, UVM_DEFAULT)
    `uvm_field_int(axi_data_width, UVM_DEFAULT)
    `uvm_field_int(axi_id_width, UVM_DEFAULT)
    `uvm_field_object(addr_map, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "debug_sys_cfg");
    super.new(name);
    addr_map = debug_sys_addr_map::type_id::create("addr_map");
    addr_map.configure_standalone();
    apply_plusargs();
  endfunction

  // ==========================================
  // 从 plusarg 读取配置
  // 使用方法: +debug_port_proto=JTAG 或 +debug_port_proto=SWD
  // ==========================================
  virtual function void apply_plusargs();
    string proto_str;

    // 协议选择
    if ($value$plusargs("debug_port_proto=%s", proto_str)) begin
      case (proto_str.tolower())
        "jtag": port_protocol = PROTO_JTAG;
        "swd":  port_protocol = PROTO_SWD;
        default: begin
          `uvm_warning("CFG", $sformatf(
            "Unknown protocol '%s', defaulting to JTAG", proto_str))
          port_protocol = PROTO_JTAG;
        end
      endcase
      `uvm_info("CFG", $sformatf("Debug port protocol set to %s (from plusarg)",
        port_protocol.name()), UVM_LOW)
    end else begin
      `uvm_info("CFG", $sformatf("No +debug_port_proto plusarg, default = %s",
        port_protocol.name()), UVM_MEDIUM)
    end
  endfunction

  // 便捷方法: 判断当前是不是 JTAG
  virtual function bit is_jtag();
    return (port_protocol == PROTO_JTAG);
  endfunction

  // 便捷方法: 判断当前是不是 SWD
  virtual function bit is_swd();
    return (port_protocol == PROTO_SWD);
  endfunction

endclass

`endif
