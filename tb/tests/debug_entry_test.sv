`ifndef DEBUG_ENTRY_TEST_SV
`define DEBUG_ENTRY_TEST_SV

class debug_entry_test extends debug_port_base_test;
  `uvm_component_utils(debug_entry_test)

  function new(string name = "debug_entry_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_entry_smoke();
    phase.drop_objection(this);
  endtask
endclass

`endif

