`ifndef DEBUG_TRACE_TEST_SV
`define DEBUG_TRACE_TEST_SV

class debug_trace_test extends debug_port_base_test;
  `uvm_component_utils(debug_trace_test)

  function new(string name = "debug_trace_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_trace_smoke();
    phase.drop_objection(this);
  endtask
endclass

`endif

