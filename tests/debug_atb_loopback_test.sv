`ifndef DEBUG_ATB_LOOPBACK_TEST_SV
`define DEBUG_ATB_LOOPBACK_TEST_SV

// ==========================================
// ATB Loopback Test
// ==========================================
// How this test works:
//
// 1. Reset Phase (automatic)
//    ?? debug_reset_sequence runs on reset sequencer
//
// 2. Main Phase
//    ?? start debug_atb_test_sequence on env.vseqr.atb_sequencer
//
// 3. Sequence Execution
//    ?? Creates N svt_atb_transaction
//       ?? atid = incremental (0x01, 0x02, ...)
//       ?? data = 32'hCAFEBABE ^ i
//       ?? Send to ATB master VIP
//
// 4. Scoreboard Comparison (AUTOMATIC!)
//    ?? atb_env.master[0].monitor -> connects to scoreboard.atb_exp
//    ?  (Expected packet - what we sent from master)
//    ?? atb_env.slave[0].monitor -> connects to scoreboard.atb_actual
//    ?  (Actual packet - what arrived at slave)
//    ?? compare_atb() pops both queues and calls transaction.compare()
//
// 5. Report Phase (automatic)
//    ?? Prints atb_matches / atb_mismatches counters
//
class debug_atb_loopback_test extends debug_port_base_test;

  `uvm_component_utils(debug_atb_loopback_test)

  function new(string name = "debug_atb_loopback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    debug_atb_test_sequence atb_seq;

    phase.raise_objection(this);
    `uvm_info("TEST", "=== START: debug_atb_loopback_test ===", UVM_LOW)

    atb_seq = debug_atb_test_sequence::type_id::create("atb_seq");
    atb_seq.sequence_length = 8; // Send 8 packets
    atb_seq.start(env.vseqr.atb_sequencer);

    `uvm_info("TEST", "=== END: debug_atb_loopback_test ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif