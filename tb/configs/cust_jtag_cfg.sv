// ==========================================
// Custom JTAG Configuration
// ==========================================
`ifndef CUST_JTAG_CFG_SV
`define CUST_JTAG_CFG_SV

class cust_jtag_cfg extends svt_jtag_agent_configuration;

  `uvm_object_utils(cust_jtag_cfg)

  function new(string name = "cust_jtag_cfg");
    super.new(name);

    this.is_active = 1'b1;
    this.mode_of_operation = svt_jtag_types::MODE_SYNCHRONOUS;
    this.jtag_device_type = svt_jtag_types::JTAG_DRIVER;
    this.inst_binary_for_device_identification_reg = 8'h06;
    this.protocol_checks_enable = 1'b1;
    this.coverage_enable = 1'b1;

  endfunction

endclass

`endif