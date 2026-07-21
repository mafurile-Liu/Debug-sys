`ifndef DEBUG_PORT_SMOKE_TEST_SV
`define DEBUG_PORT_SMOKE_TEST_SV

class debug_port_smoke_test extends debug_port_base_test;
  `uvm_component_utils(debug_port_smoke_test)

  function new(string name = "debug_port_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge env.vseqr.reset_vif.clk);
    if (env.apb_master_env == null || env.apb_slave_env == null) begin
      `uvm_error("NO_APB", "APB RAL environment was not built")
    end
    if (env.axi_monitor_env == null) begin
      `uvm_error("NO_AXI", "AXI passive monitor environment was not built")
    end
    if (env.atb_env == null) begin
      `uvm_error("NO_ATB", "ATB environment was not built")
    end
`ifdef DEBUG_PORT_JTAG
    `uvm_info("SMOKE", "JTAG + APB RAL + AXI monitor + ATB environment is alive", UVM_LOW)
`elsif DEBUG_PORT_SWD
    `uvm_info("SMOKE", "SWD + APB RAL + AXI monitor + ATB environment is alive", UVM_LOW)
`endif
    phase.drop_objection(this);
  endtask
endclass

`endif
