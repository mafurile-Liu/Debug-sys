`ifndef DEBUG_DAP_REG_ACCESS_TEST_SV
`define DEBUG_DAP_REG_ACCESS_TEST_SV

// ==========================================
// DAP Register Access Test
// ==========================================
//
// This test demonstrates the new DAP register access sequence interface.
// The sequence accepts:
//   - is_write: 1 for write, 0 for read
//   - reg_addr: 2-bit register address (DP registers)
//   - write_data: 32-bit data for writes
//   - is_ap_access: 1 for AP access (generates APB), 0 for DP access
//
// JTAG-DP PROTOCOL IMPLEMENTATION:
//
// Each access requires:
//   1. IR Shift (4 bits) - select DPACC or APACC instruction
//   2. DR Shift (35 bits) - W_nR bit + 32-bit data + 2-bit ACK
//
// This is the correct Arm Debug Port protocol, not just simple DR shifts.
//
// ==========================================

class debug_dap_reg_access_test extends debug_port_base_test;

  `uvm_component_utils(debug_dap_reg_access_test)

  function new(string name = "debug_dap_reg_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    debug_dap_reg_access_sequence dap_seq;
    bit [31:0] read_result;

    phase.raise_objection(this);
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "START: debug_dap_reg_access_test", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "This test demonstrates the DAP register access sequence", UVM_MEDIUM)
    `uvm_info("TEST", "Interface: is_write, reg_addr, write_data, is_ap_access", UVM_MEDIUM)
    `uvm_info("TEST", "Implementation: IR shift (4 bits) + DR shift (35 bits)", UVM_MEDIUM)
    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // Test 1: DP Register Read (DPIDR/IDCODE at addr 0)
    // ==========================================
    `uvm_info("TEST", "----- TEST 1: DP Register Read (ADDR=0) -----", UVM_LOW)
    dap_seq = debug_dap_reg_access_sequence::type_id::create("dap_seq_dp_read");
    dap_seq.is_write     = 1'b0;        // Read operation
    dap_seq.reg_addr     = 2'b00;       // DPIDR register (addr 0)
    dap_seq.is_ap_access = 1'b0;        // DP access (not AP)
    dap_seq.start(env.vseqr.jtag_sequencer);
    read_result = dap_seq.read_data;
    `uvm_info("TEST", $sformatf("Test 1 Result: Read 0x%08h from DP reg 0", read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // Test 2: DP Register Write (CTRL/STAT at addr 1)
    // ==========================================
    `uvm_info("TEST", "----- TEST 2: DP Register Write (ADDR=1) -----", UVM_LOW)
    dap_seq = debug_dap_reg_access_sequence::type_id::create("dap_seq_dp_write");
    dap_seq.is_write     = 1'b1;        // Write operation
    dap_seq.reg_addr     = 2'b01;       // CTRL/STAT register (addr 1)
    dap_seq.write_data   = 32'h50000000; // Write value (CSYSPWRUPREQ + CDBGPWRUPREQ)
    dap_seq.is_ap_access = 1'b0;        // DP access
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("Test 2 Result: Wrote 0x%08h to DP reg 1", dap_seq.write_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // Test 3: DP Register Read-back (CTRL/STAT at addr 1)
    // ==========================================
    `uvm_info("TEST", "----- TEST 3: DP Register Read-back (ADDR=1) -----", UVM_LOW)
    dap_seq = debug_dap_reg_access_sequence::type_id::create("dap_seq_dp_readback");
    dap_seq.is_write     = 1'b0;        // Read operation
    dap_seq.reg_addr     = 2'b01;       // CTRL/STAT register (addr 1)
    dap_seq.is_ap_access = 1'b0;        // DP access
    dap_seq.start(env.vseqr.jtag_sequencer);
    read_result = dap_seq.read_data;
    `uvm_info("TEST", $sformatf("Test 3 Result: Read 0x%08h from DP reg 1", read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // Test 4: AP Register Access (generates APB transaction)
    // ==========================================
    // Note: AP access via JTAG-DP causes the AP to generate APB transactions
    // This is how the DAP converts JTAG/SWD to APB bus accesses
    `uvm_info("TEST", "----- TEST 4: AP Register Write (APB access) -----", UVM_LOW)
    `uvm_info("TEST", "This access would generate an APB write in a real DAP", UVM_MEDIUM)
    dap_seq = debug_dap_reg_access_sequence::type_id::create("dap_seq_ap_write");
    dap_seq.is_write     = 1'b1;        // Write operation
    dap_seq.reg_addr     = 2'b00;       // AP register address (through SELECT)
    dap_seq.write_data   = 32'hDEADBEEF; // Test data
    dap_seq.is_ap_access = 1'b1;        // AP access (generates APB transaction!)
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("Test 4 Result: AP write 0x%08h (would create APB xfer)",
      dap_seq.write_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // Test 5: AP Register Read (generates APB read)
    // ==========================================
    `uvm_info("TEST", "----- TEST 5: AP Register Read (APB read) -----", UVM_LOW)
    `uvm_info("TEST", "This access would generate an APB read in a real DAP", UVM_MEDIUM)
    dap_seq = debug_dap_reg_access_sequence::type_id::create("dap_seq_ap_read");
    dap_seq.is_write     = 1'b0;        // Read operation
    dap_seq.reg_addr     = 2'b00;       // AP register address
    dap_seq.is_ap_access = 1'b1;        // AP access (generates APB transaction!)
    dap_seq.start(env.vseqr.jtag_sequencer);
    read_result = dap_seq.read_data;
    `uvm_info("TEST", $sformatf("Test 5 Result: AP read 0x%08h (from APB xfer)", read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "END: debug_dap_reg_access_test", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
