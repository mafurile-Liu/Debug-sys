`ifndef DEBUG_APB_SCENARIO_TEST_SV
`define DEBUG_APB_SCENARIO_TEST_SV

// APB Scenario Test - Full Register BIST Scenario
// Enables:
//   - Register Shadow Model (Scoreboard)
//   - Coverage collection
//   - Full RAL access via Virtual Sequencer
class debug_apb_scenario_test extends debug_port_base_test;

  `uvm_component_utils(debug_apb_scenario_test)

  function new(string name = "debug_apb_scenario_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.enable_coverage = 1'b1;
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "=== debug_apb_scenario_test START ===", UVM_LOW)
    `uvm_info("TEST", "Testing: Full Register BIST Scenario", UVM_LOW)
    run_apb_scenario_test();
    `uvm_info("TEST", "=== debug_apb_scenario_test COMPLETED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif