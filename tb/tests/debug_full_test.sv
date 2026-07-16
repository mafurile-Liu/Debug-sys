`ifndef DEBUG_FULL_TEST_SV
`define DEBUG_FULL_TEST_SV

class debug_full_test extends debug_port_base_test;
  `uvm_component_utils(debug_full_test)

  function new(string name = "debug_full_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_entry_smoke();
    run_reg_smoke();
    run_trace_smoke();
    repeat (10) @(posedge env.vseqr.reset_vif.clk);
    phase.drop_objection(this);
  endtask
endclass

`endif

