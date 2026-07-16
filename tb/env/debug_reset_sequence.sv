`ifndef DEBUG_RESET_SEQUENCE_SV
`define DEBUG_RESET_SEQUENCE_SV

class debug_reset_sequence extends
  uvm_sequence#(uvm_sequence_item, uvm_sequence_item);

  `uvm_object_utils(debug_reset_sequence)
  `uvm_declare_p_sequencer(debug_sys_virtual_sequencer)

  function new(string name = "debug_reset_sequence");
    super.new(name);
  endfunction

  virtual task body();
    p_sequencer.reset_vif.reset_n <= 1'b1;
    repeat (2) @(posedge p_sequencer.reset_vif.clk);
    p_sequencer.reset_vif.reset_n <= 1'b0;
    repeat (5) @(posedge p_sequencer.reset_vif.clk);
    p_sequencer.reset_vif.reset_n <= 1'b1;
    repeat (2) @(posedge p_sequencer.reset_vif.clk);
    `uvm_info("RESET_DONE", "Debug port reset completed", UVM_LOW)
  endtask
endclass

`endif
