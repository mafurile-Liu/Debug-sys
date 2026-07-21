`ifndef DEBUG_APB_REG_TEST_SV
`define DEBUG_APB_REG_TEST_SV

// APB Register Test - RAL-based register access test
// Follows AI_DESIGN_GUIDE architecture principles:
//   - Test calls sequence on Virtual Sequencer
//   - Sequence uses RAL, no direct transaction construction
//   - No hardcoded addresses
class debug_apb_reg_test extends debug_port_base_test;

  `uvm_component_utils(debug_apb_reg_test)

  function new(string name = "debug_apb_reg_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "=== debug_apb_reg_test START ===", UVM_LOW)
    run_apb_reg_test();
    `uvm_info("TEST", "=== debug_apb_reg_test COMPLETED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif