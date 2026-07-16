`ifndef DEBUG_SYS_CFG_SV
`define DEBUG_SYS_CFG_SV

class debug_sys_cfg extends uvm_object;
  // AXI is intentionally unconnected in standalone mode; enable after DUT hookup.
  bit enable_checks = 1'b0;
  bit enable_coverage = 1'b1;
  bit enable_apb_ral = 1'b1;
  bit enable_axi_monitor = 1'b1;
  bit enable_atb = 1'b1;
  int unsigned swd_turnaround = 1;
  int unsigned axi_data_width = 32;
  int unsigned axi_id_width = 4;

  `uvm_object_utils_begin(debug_sys_cfg)
    `uvm_field_int(enable_checks, UVM_DEFAULT)
    `uvm_field_int(enable_coverage, UVM_DEFAULT)
    `uvm_field_int(enable_apb_ral, UVM_DEFAULT)
    `uvm_field_int(enable_axi_monitor, UVM_DEFAULT)
    `uvm_field_int(enable_atb, UVM_DEFAULT)
    `uvm_field_int(swd_turnaround, UVM_DEFAULT)
    `uvm_field_int(axi_data_width, UVM_DEFAULT)
    `uvm_field_int(axi_id_width, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "debug_sys_cfg");
    super.new(name);
  endfunction
endclass

`endif
