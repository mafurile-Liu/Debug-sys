`ifndef DEBUG_ATB_TEST_SEQUENCE_SV
`define DEBUG_ATB_TEST_SEQUENCE_SV

// ==========================================
// ATB Test Sequence
// ==========================================
// Sends ATB trace packets through master and verifies
// they arrive at slave with correct data.
//
// Scoreboard automatically compares expected vs actual
// via the compare_atb() function.
// ==========================================

class debug_atb_test_sequence extends uvm_sequence#(svt_atb_transaction);

  `uvm_object_utils(debug_atb_test_sequence)
  `uvm_declare_p_sequencer(svt_atb_system_sequencer)

  rand int unsigned sequence_length;

  constraint reasonable_length { sequence_length inside {[4:16]}; }

  function new(string name = "debug_atb_test_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_atb_transaction tr;
    `uvm_info("ATB_SEQ", "Starting ATB trace packet sequence", UVM_LOW)

    for (int i = 0; i < sequence_length; i++) begin
      `uvm_create(tr)

      // ==========================================
      // ATB Transaction Fields Configuration
      // ==========================================
      tr.addr_valid    = 1'b1;           // Address is valid (optional)
      tr.atid          = 7'h01 + i[6:0]; // ATID: CoreSight trace source ID
      tr.data          = 32'hCAFEBABE ^ i; // Trace data
      tr.data_valid    = 1'b1;           // Data is valid
      tr.flush_request = 1'b0;           // No flush
      tr.sync_request  = 1'b0;           // No sync request
      tr.ready         = 1'b1;           // Ready for data

      `uvm_info("ATB_SEQ", $sformatf("Packet %0d: ATID=0x%0h DATA=0x%08h",
        i, tr.atid, tr.data), UVM_MEDIUM)

      `uvm_send(tr)
      get_response(rsp);
    end

    `uvm_info("ATB_SEQ", $sformatf("Completed %0d ATB packets", sequence_length), UVM_LOW)
  endtask

endclass

`endif