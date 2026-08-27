`ifndef DEBUG_APB_XFER_TEST_SV
`define DEBUG_APB_XFER_TEST_SV

/**
 * APB Transfer Verification Test
 *
 * This test starts the debug_apb_xfer_sequence in main_phase.
 * The sequence drives transactions through apb_master_env.master.sequencer.
 * Scoreboard and slave memory sequence are configured by base_test.
 */
class debug_apb_xfer_test extends debug_port_base_test;
  `uvm_component_utils(debug_apb_xfer_test)

  function new(string name = "debug_apb_xfer_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_apb_xfer();
    phase.drop_objection(this);
  endtask
endclass

`endif
