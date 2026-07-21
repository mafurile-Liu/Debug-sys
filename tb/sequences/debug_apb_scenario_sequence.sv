`ifndef DEBUG_APB_SCENARIO_SEQUENCE_SV
`define DEBUG_APB_SCENARIO_SEQUENCE_SV

// APB Scenario Sequence Layer
// Combines feature sequences into complete test scenarios
//
// Supported scenarios:
//   SCENARIO_RESET_SELFTEST  - Verify all registers after reset
//   SCENARIO_FULL_REG_BIST   - Full Built-In Self-Test sequence
//   SCENARIO_TRACE_ENABLE     - Trace subsystem enable sequence
`include "debug_apb_reg_test_sequence.sv"

class debug_apb_scenario_sequence extends debug_apb_reg_test_sequence;

  typedef enum {
    SCENARIO_RESET_SELFTEST,
    SCENARIO_FULL_REG_BIST,
    SCENARIO_TRACE_ENABLE
  } scenario_type_e;

  rand scenario_type_e scenario_type;

  `uvm_object_utils(debug_apb_scenario_sequence)

  function new(string name = "debug_apb_scenario_sequence");
    super.new(name);
    scenario_type = SCENARIO_FULL_REG_BIST;
  endfunction

  virtual task body();
    `uvm_info("SCENARIO", "APB Scenario sequence started", UVM_LOW)

    case (scenario_type)
      SCENARIO_RESET_SELFTEST:  run_reset_selftest();
      SCENARIO_FULL_REG_BIST:   run_full_reg_bist();
      SCENARIO_TRACE_ENABLE:     run_trace_enable();
      default:                   run_full_reg_bist();
    endcase

    `uvm_info("SCENARIO", "APB Scenario sequence completed", UVM_LOW)
  endtask

  // Scenario: Run reset state verification only
  virtual task run_reset_selftest();
    uvm_reg_data_t readback;
    `uvm_info("SCENARIO", "Running Reset Selftest", UVM_MEDIUM)

    // Verify IDCODE reset value
    read_reg(p_sequencer.regmodel.idcode, readback);
    if (readback !== p_sequencer.regmodel.idcode.get_reset()) begin
      `uvm_error("RESET_TEST", $sformatf(
        "IDCODE reset value wrong: expected=0x%08h, got=0x%08h",
        p_sequencer.regmodel.idcode.get_reset(), readback))
    end

    // Verify CONTROL reset value is 0
    read_reg(p_sequencer.regmodel.control, readback);
    if (readback !== 32'h0) begin
      `uvm_error("RESET_TEST", $sformatf(
        "CONTROL reset value wrong: expected=0x0, got=0x%08h", readback))
    end

    `uvm_info("SCENARIO", "Reset selftest PASSED", UVM_MEDIUM)
  endtask

  // Scenario: Full Built-In Self-Test (BIST)
  virtual task run_full_reg_bist();
    `uvm_info("SCENARIO", "Running Full Register BIST", UVM_MEDIUM)
    run_reset_selftest();
    run_random_test();
    `uvm_info("SCENARIO", "Full Register BIST PASSED", UVM_MEDIUM)
  endtask

  // Scenario: Trace enable sequence
  virtual task run_trace_enable();
    `uvm_info("SCENARIO", "Running Trace Enable Scenario", UVM_MEDIUM)
    write_and_verify_reg(p_sequencer.regmodel.trace_control, 32'h00000000);
    write_and_verify_reg(p_sequencer.regmodel.trace_control, 32'h00000001);
    verify_status();
    `uvm_info("SCENARIO", "Trace Enable Scenario PASSED", UVM_MEDIUM)
  endtask

endclass

`endif