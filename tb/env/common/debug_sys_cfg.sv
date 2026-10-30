`ifndef DEBUG_SYS_CFG_SV
`define DEBUG_SYS_CFG_SV

// ==========================================
// Debug System Configuration
// ==========================================
// ???????, ?? plusarg ??????
//
// ????:
//   +debug_port_proto=JTAG  -> ?? JTAG ??
//   +debug_port_proto=SWD   -> ?? SWD ??
// ==========================================

typedef enum {
  PROTO_JTAG,  // JTAG ??
  PROTO_SWD    // SWD ??
} debug_proto_e;

class debug_sys_cfg extends uvm_object;
  // AXI is intentionally unconnected in standalone mode; enable after DUT hookup.
  bit          enable_checks     = 1'b0;
  bit          enable_coverage   = 1'b1;
  bit          enable_apb_ral     = 1'b1;
  bit          enable_axi_monitor = 1'b1;
  bit          enable_atb        = 1'b1;
  bit          enable_predictor  = 1'b1; // route through predictor/scoreboard
  bit          enable_ect        = 1'b0;
  int unsigned swd_turnaround    = 1;
  int unsigned axi_data_width    = 32;
  int unsigned axi_id_width      = 4;

  // ???????? (????? plusarg ??)
  debug_proto_e port_protocol = PROTO_JTAG;  // ?? JTAG

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
    `uvm_field_int(enable_ect, UVM_DEFAULT)
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
  // ? plusarg ????
  // ????: +debug_port_proto=JTAG ? +debug_port_proto=SWD
  // ==========================================
  virtual function void apply_plusargs();
    string proto_str;

    // ????
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

  // ????: ??????? JTAG
  virtual function bit is_jtag();
    return (port_protocol == PROTO_JTAG);
  endfunction

  // ????: ??????? SWD
  virtual function bit is_swd();
    return (port_protocol == PROTO_SWD);
  endfunction

endclass

`endif
