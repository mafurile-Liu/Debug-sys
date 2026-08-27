`ifndef DEBUG_DAP_REG_ACCESS_SEQUENCE_SV
`define DEBUG_DAP_REG_ACCESS_SEQUENCE_SV

// ==========================================
// DAP Register Access Sequence
// ==========================================
// This sequence provides a high-level interface to access DAP registers
// via JTAG or SWD protocol. It handles the low-level IR and DR shifts
// required by the JTAG-DP protocol.
//
// USAGE:
//   1. Set is_write = 1 for write, 0 for read
//   2. Set reg_addr[3:2] for DP register address (A[3:2] in JTAG-DP)
//   3. For writes: set write_data = value to write
//   4. For reads: read_data will contain the read value after sequence completes
//
// JTAG-DP PROTOCOL FLOW:
//   For each register access:
//     1. Go to Shift-IR state
//     2. Shift 4-bit IR instruction (DPACC or APACC)
//     3. Go to Shift-DR state
//     4. Shift 35-bit DR (1-bit WnR + 32-bit data + 2-bit ACK)
//
// ARM JTAG-DP INSTRUCTIONS (4-bit IR):
//   0b1000 = ABORT
//   0b1010 = DPACC (Debug Port Access)
//   0b1011 = APACC (Access Port Access)
//   0b1110 = IDCODE
//   0b1111 = BYPASS
//
// DR FORMAT (35 bits total for DPACC/APACC):
//   Bit 0:    ACK[0]
//   Bit 1:    ACK[1]
//   Bits 2-33: Data[31:0]
//   Bit 34:   W_nR (1=Write, 0=Read)
//
// ==========================================

class debug_dap_reg_access_sequence extends uvm_sequence#(svt_jtag_transaction);

  `uvm_object_utils(debug_dap_reg_access_sequence)
  `uvm_declare_p_sequencer(svt_jtag_transaction_sequencer)

  // ==========================================
  // USER CONTROL - Set these before starting sequence
  // ==========================================

  // Access type: 1 = write, 0 = read
  rand bit is_write;

  // Register address (2 bits for DP: A[3:2] of the address)
  // For DP registers:
  //   2'b00 = DPIDR/IDCODE
  //   2'b01 = CTRL/STAT
  //   2'b10 = SELECT
  //   2'b11 = RDBUFF
  rand bit [1:0] reg_addr;

  // Write data (used when is_write = 1)
  rand bit [31:0] write_data;

  // Read data (valid after sequence completes when is_write = 0)
  bit [31:0] read_data;

  // Access Port select (0 = DP, 1 = AP)
  // AP accesses will generate APB transactions on the AP bus
  rand bit is_ap_access;

  // ==========================================
  // JTAG-DP Protocol Constants
  // ==========================================

  // JTAG-DP IR instructions (4-bit)
  localparam IR_DPACC  = 4'b1010;  // Debug Port Access
  localparam IR_APACC  = 4'b1011;  // Access Port Access
  localparam IR_IDCODE = 4'b1110;  // IDCODE
  localparam IR_ABORT  = 4'b1000;  // Abort
  localparam IR_BYPASS = 4'b1111;  // Bypass

  // IR width for JTAG-DP is typically 4 bits
  localparam IR_WIDTH = 4;

  // DR width for DPACC/APACC is 35 bits (WnR[1] + DATA[32] + ACK[2])
  localparam DR_WIDTH = 35;

  function new(string name = "debug_dap_reg_access_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_jtag_transaction tr;
    svt_jtag_transaction rsp;
    bit [34:0] dr_tx_data;  // 35-bit DR: W_nR[34] + Data[33:2] + ACK[1:0]
    bit [34:0] dr_rx_data;
    bit [3:0] ir_instr;

    `uvm_info("DAP_SEQ", $sformatf("Starting DAP Register Access: %s ADDR=0x%0h",
      is_write ? "WRITE" : "READ", reg_addr), UVM_LOW)

    // ==========================================
    // Step 1: Reset TAP state machine (if first access)
    // ==========================================
    `uvm_info("DAP_SEQ", "Step 1: TAP Reset (5 TCK cycles)", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RESET_STATE;
    tr.num_tck_cycles = 5;
    `uvm_send(tr)

    // ==========================================
    // Step 2: Select instruction (Shift-IR)
    // ==========================================
    // Select DPACC or APACC based on is_ap_access
    ir_instr = is_ap_access ? IR_APACC : IR_DPACC;

    `uvm_info("DAP_SEQ", $sformatf("Step 2: Shift-IR, Instruction=0x%0h (%s)",
      ir_instr, is_ap_access ? "APACC" : "DPACC"), UVM_MEDIUM)

    // Go to Shift-IR state
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_IR_STATE;
    `uvm_send(tr)

    // Shift IR value
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_IR;
    tr.data_width = IR_WIDTH;
    tr.tx_data = new[1];
    tr.tx_data[0] = ir_instr;
    tr.num_tck_cycles = IR_WIDTH;
    `uvm_send(tr)
    get_response(rsp);

    `uvm_info("DAP_SEQ", $sformatf("IR shifted out: 0x%0h", ir_instr), UVM_HIGH)

    // ==========================================
    // Step 3: Register Access (Shift-DR)
    // ==========================================
    // DR Format (35 bits):
    //   Bit 34:    W_nR (1 = Write, 0 = Read)
    //   Bits 33-2: Data[31:0]
    //   Bits 1-0:  ACK (response)
    //
    // For reads:  Send W_nR=0, Data=ignored, Receive Data[31:0] + ACK
    // For writes: Send W_nR=1, Data=value,   Receive ACK

    // Go to Shift-DR state
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
    `uvm_send(tr)

    // Construct DR transmit data
    if (is_write) begin
      // Write operation: W_nR=1, Data=write_data, ACK field ignored on TX
      dr_tx_data[34]    = 1'b1;          // W_nR = 1 (Write)
      dr_tx_data[33:2]  = write_data;    // Data to write
      dr_tx_data[1:0]   = 2'b00;         // ACK bits (ignored for TX)
    end else begin
      // Read operation: W_nR=0, Data field ignored, ACK ignored on TX
      dr_tx_data[34]    = 1'b0;          // W_nR = 0 (Read)
      dr_tx_data[33:2]  = 32'h00000000;  // Data field (ignore for read)
      dr_tx_data[1:0]   = 2'b00;         // ACK bits (ignored for TX)
    end

    `uvm_info("DAP_SEQ", $sformatf("Step 3: Shift-DR, TX=0x%09h (35 bits)", dr_tx_data),
      UVM_MEDIUM)

    // Shift DR (35 bits)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR;
    tr.data_width = DR_WIDTH;
    tr.tx_data = new[1];
    tr.tx_data[0] = dr_tx_data;
    tr.num_tck_cycles = DR_WIDTH;
    `uvm_send(tr)
    get_response(rsp);

    dr_rx_data = rsp.rx_data[0][34:0];

    `uvm_info("DAP_SEQ", $sformatf("DR received: 0x%09h", dr_rx_data), UVM_HIGH)

    // ==========================================
    // Step 4: Extract results
    // ==========================================

    // ACK field (bits 1:0)
    // 00 = OK/WAIT
    // 01 = FAULT
    // 10 = WAIT
    // 11 = Reserved
    `uvm_info("DAP_SEQ", $sformatf("ACK = %2b", dr_rx_data[1:0]), UVM_MEDIUM)

    if (dr_rx_data[1:0] != 2'b00) begin
      `uvm_warning("DAP_SEQ", $sformatf(
        "Non-zero ACK received: %2b - may indicate WAIT or FAULT", dr_rx_data[1:0]))
    end

    if (!is_write) begin
      // Extract read data from DR
      read_data = dr_rx_data[33:2];
      `uvm_info("DAP_SEQ", $sformatf("READ DATA = 0x%08h", read_data), UVM_LOW)
    end else begin
      `uvm_info("DAP_SEQ", $sformatf("WRITE DATA = 0x%08h completed", write_data), UVM_LOW)
    end

    // ==========================================
    // Step 5: Return to Run-Test-Idle
    // ==========================================
    `uvm_info("DAP_SEQ", "Step 5: Return to Run-Test-Idle", UVM_MEDIUM)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RUN_TEST_IDLE_STATE;
    tr.num_tck_cycles = 10;
    `uvm_send(tr)

    `uvm_info("DAP_SEQ", "DAP register access sequence completed", UVM_LOW)
  endtask

endclass

`endif
