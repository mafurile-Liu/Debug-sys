`ifndef DEBUG_DP_IDCODE_SEQUENCE_SV
`define DEBUG_DP_IDCODE_SEQUENCE_SV

// ==========================================
// Debug Port IDCODE Read Sequence
// ==========================================
// Reads the IDCODE register from the Debug Port via JTAG/SWD.
//
// Supported protocols:
//   - JTAG: Uses JTAG TAP state machine
//   - SWD: Uses SWD read protocol
//
// Typical flow (JTAG):
//   1. Enter Test-Logic-Reset
//   2. Go to Run-Test-Idle
//   3. Go to Shift-DR
//   4. Shift out 32-bit IDCODE
//   5. Return to Run-Test-Idle
//
// The SVT VIP handles low-level protocol timing.
// This sequence just constructs the transaction.
// ==========================================

class debug_dp_idcode_sequence extends uvm_sequence#(svt_jtag_transaction);

  `uvm_object_utils(debug_dp_idcode_sequence)
  `uvm_declare_p_sequencer(svt_jtag_transaction_sequencer)

  // Expected IDCODE value (Arm Debug Port)
  parameter bit [31:0] EXPECTED_IDCODE = 32'hBA000047;

  function new(string name = "debug_dp_idcode_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_jtag_transaction tr;
    svt_jtag_transaction rsp;
    bit [31:0] read_data;

    `uvm_info("DP_SEQ", "Starting Debug Port IDCODE read sequence", UVM_LOW)

    // ==========================================
    // Step 1: Reset TAP state machine
    // ==========================================
    `uvm_info("DP_SEQ", "Step 1: TAP Reset (5 TCK cycles)", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RESET_STATE;
    tr.num_tck_cycles = 5;
    `uvm_send(tr)

    // ==========================================
    // Step 2: Go to Shift-DR state
    // ==========================================
    `uvm_info("DP_SEQ", "Step 2: Go to Shift-DR", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
    `uvm_send(tr)

    // ==========================================
    // Step 3: Shift out 32-bit IDCODE
    // ==========================================
    `uvm_info("DP_SEQ", "Step 3: Shift out 32-bit IDCODE", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR;
    tr.data_width = 32;
    tr.tx_data = new[1];
    tr.tx_data[0] = 32'h00000000;  // Send zeros while shifting out
    tr.num_tck_cycles = 32;
    `uvm_send(tr)
    get_response(rsp);

    read_data = rsp.rx_data[0];
    `uvm_info("DP_SEQ", $sformatf("IDCODE READ: 0x%08h", read_data), UVM_LOW)

    // ==========================================
    // Step 4: Verify IDCODE
    // ==========================================
    if (read_data == EXPECTED_IDCODE) begin
      `uvm_info("DP_SEQ", $sformatf("SUCCESS: IDCODE matches expected (0x%08h)",
        EXPECTED_IDCODE), UVM_LOW)
    end else begin
      `uvm_error("DP_SEQ", $sformatf(
        "IDCODE MISMATCH! Expected 0x%08h, Got 0x%08h",
        EXPECTED_IDCODE, read_data))
    end

    // ==========================================
    // Step 5: Return to Run-Test-Idle
    // ==========================================
    `uvm_info("DP_SEQ", "Step 5: Return to Run-Test-Idle", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RUN_TEST_IDLE_STATE;
    tr.num_tck_cycles = 10;
    `uvm_send(tr)

    `uvm_info("DP_SEQ", "IDCODE sequence completed", UVM_LOW)
  endtask

endclass

`endif
