`ifndef DEBUG_DP_IDCODE_TEST_SV
`define DEBUG_DP_IDCODE_TEST_SV

// ==========================================
// Debug Port IDCODE Read Test
// ==========================================
//
// FULL EXECUTION FLOW:
//
// +-----------------------------------------+
// | 1. UVM Phases Start                     |
// +-----------------------------------------+
//                |
// +-----------------------------------------+
// | 2. build_phase                           |
// +-----------------------------------------+
//                |-- debug_port_base_test creates cfg
//                |-- cfg is passed to env via config_db
//                |-- env builds all agents + VIP
//
// +-----------------------------------------+
// | 3. reset_phase (AUTOMATIC)              |
// +-----------------------------------------+
//                |-- debug_reset_sequence runs
//                   - toggles reset_n on debug_reset_if
//
// +-----------------------------------------+
// | 4. configure_phase (AUTOMATIC)          |
// +-----------------------------------------+
//                |-- VIPs initialize internal state
//
// +-----------------------------------------+
// | 5. main_phase (OUR CODE STARTS HERE)    |
// +-----------------------------------------+
//                |
//                |-- phase.raise_objection(this)
//                |  (Prevents UVM from ending prematurely)
//                |
//                |-- Create debug_dp_idcode_sequence
//                |  |
//                |-- seq.start(env.vseqr.jtag_sequencer)
//                |  |
//                |  |-- Step 1: Reset TAP (5 TCK cycles)
//                |  |  |-- JTAG VIP toggles TCK
//                |  |  |-- loopback module connects TDI to TDO
//                |  |
//                |  |-- Step 2: Go to SHIFT-DR state
//                |  |  |-- TAP state machine transitions
//                |  |
//                |  |-- Step 3: Shift 32 bits of IDCODE
//                |  |  |-- Master sends TDI (0s)
//                |  |  |-- Slave captures TDO (IDCODE value)
//                |  |  |-- Loopback: TDI directly wired to TDO
//                |  |
//                |  |-- Step 4: Verify IDCODE == 0xBA000047
//                |
//                |-- phase.drop_objection(this)
//
// +-----------------------------------------+
// | 6. check_phase (AUTOMATIC)              |
// +-----------------------------------------+
//                |-- scoreboard checks for
//                   unmatched transactions
//
// +-----------------------------------------+
// | 7. report_phase (AUTOMATIC)             |
// +-----------------------------------------+
//                |-- Print matches/mismatches
//                |-- Print coverage stats
//
// ==========================================

class debug_dp_idcode_test extends debug_port_base_test;

  `uvm_component_utils(debug_dp_idcode_test)

  function new(string name = "debug_dp_idcode_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    debug_dp_idcode_sequence dp_seq;

    phase.raise_objection(this);
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "START: debug_dp_idcode_test", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "This test reads the IDCODE register from the JTAG Debug Port", UVM_MEDIUM)
    `uvm_info("TEST", "Expected IDCODE: 0xBA000047 (Arm Debug Port)", UVM_MEDIUM)
    `uvm_info("TEST", "", UVM_LOW)

    // Start sequence on JTAG port sequencer
    // (Same sequencer works for both JTAG and SWD - VIP abstracts the protocol)
    dp_seq = debug_dp_idcode_sequence::type_id::create("dp_seq");
    dp_seq.start(env.vseqr.jtag_sequencer);

    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "END: debug_dp_idcode_test", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
