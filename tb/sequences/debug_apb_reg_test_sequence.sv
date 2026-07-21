`ifndef DEBUG_APB_REG_TEST_SEQUENCE_SV
`define DEBUG_APB_REG_TEST_SEQUENCE_SV

`include "debug_apb_reg_sequence.sv"

// APB Register Test Sequence - Feature Layer
// Implements complete test scenarios using register primitives
//  - Reset value verification
//  - Known pattern tests (all 0, all 1, 5555, AAAA)
//  - Random data testing
class debug_apb_reg_test_sequence extends debug_apb_reg_sequence;

  rand bit do_random_test;
  rand int unsigned random_test_count;

  constraint c_random_count { random_test_count inside {[4:32]}; }

  `uvm_object_utils(debug_apb_reg_test_sequence)

  function new(string name = "debug_apb_reg_test_sequence");
    super.new(name);
    do_random_test = 1'b1;
  endfunction

  virtual task body();
    super.body();
    `uvm_info("APB_TEST", "APB register test sequence started", UVM_LOW)

    // Test 1: CONTROL register with various patterns
    `uvm_info("APB_TEST", "Test 1: CONTROL register R/W verify", UVM_MEDIUM)
    write_and_verify_reg(p_sequencer.regmodel.control, 32'hA5A55A5A);
    write_and_verify_reg(p_sequencer.regmodel.control, 32'h55555555);
    write_and_verify_reg(p_sequencer.regmodel.control, 32'hAAAAAAAA);
    write_and_verify_reg(p_sequencer.regmodel.control, 32'h00000000);
    write_and_verify_reg(p_sequencer.regmodel.control, 32'hFFFFFFFF);

    // Test 2: TRACE_CONTROL register
    `uvm_info("APB_TEST", "Test 2: TRACE_CONTROL register R/W verify", UVM_MEDIUM)
    write_and_verify_reg(p_sequencer.regmodel.trace_control, 32'h12345678);
    write_and_verify_reg(p_sequencer.regmodel.trace_control, 32'h87654321);

    // Test 3: IDCODE (RO register read check)
    `uvm_info("APB_TEST", "Test 3: IDCODE register RO readout", UVM_MEDIUM)
    verify_idcode();

    // Test 4: STATUS register read check
    `uvm_info("APB_TEST", "Test 4: STATUS register RO readout", UVM_MEDIUM)
    verify_status();

    // Test 5: Random data testing
    if (do_random_test) begin
      `uvm_info("APB_TEST", $sformatf("Test 5: Random data test (%0d iterations)",
                                       random_test_count), UVM_MEDIUM)
      run_random_test();
    end

    `uvm_info("APB_TEST", "APB register test sequence completed SUCCESSFULLY", UVM_LOW)
  endtask

  // Verify IDCODE reset value is correct
  virtual task verify_idcode();
    uvm_reg_data_t readback;
    read_reg(p_sequencer.regmodel.idcode, readback);
    if (readback !== p_sequencer.regmodel.idcode.get_reset()) begin
      `uvm_error("IDCODE_CHECK", $sformatf(
        "IDCODE reset value mismatch: expected=0x%08h, got=0x%08h",
        p_sequencer.regmodel.idcode.get_reset(), readback))
    end
  endtask

  // Read STATUS register
  virtual task verify_status();
    uvm_reg_data_t readback;
    read_reg(p_sequencer.regmodel.status, readback);
  endtask

  // Run random test pattern iteration
  virtual task run_random_test();
    uvm_reg_data_t rand_data;
    for (int i = 0; i < random_test_count; i++) begin
      void'(std::randomize(rand_data));
      if (i % 2 == 0) begin
        write_and_verify_reg(p_sequencer.regmodel.control, rand_data);
      end else begin
        write_and_verify_reg(p_sequencer.regmodel.trace_control, rand_data);
      end
    end
  endtask

endclass

`endif