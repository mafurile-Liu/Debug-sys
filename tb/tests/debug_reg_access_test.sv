`ifndef DEBUG_REG_ACCESS_TEST_SV
`define DEBUG_REG_ACCESS_TEST_SV

class debug_reg_access_test extends debug_port_base_test;
  `uvm_component_utils(debug_reg_access_test)

  function new(string name = "debug_reg_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_reg_smoke();
    phase.drop_objection(this);
  endtask
endclass

`endif

