`ifndef DEBUG_DAP_APB_ACCESS_SEQUENCE_SV
`define DEBUG_DAP_APB_ACCESS_SEQUENCE_SV

// ==========================================
// DAP-to-APB ???????
// ==========================================
// ???????? 4 ?????
//
// ??:
//   is_write   - 1=APB?, 0=APB?
//   apb_addr   - 32? APB ???? (??DP?????!)
//   write_data - 32???? (??????)
//
// ??:
//   read_data  - 32???? (????????)
//
// ?????????? APB ??!?
//
// ??????? ARM DAP ????:
//   ???:
//     1. SHIFT-IR(APACC) ? SHIFT-DR[WnR=1, ADDR[3:2], DATA]
//        ? ?? APB ???
//
//   ???:
//     1. SHIFT-IR(APACC) ? SHIFT-DR[WnR=0, ADDR[3:2]]
//        ? ?? APB ???, ???? RDBUFF
//     2. SHIFT-IR(DPACC) ? SHIFT-DR ? RDBUFF ???
//        ? ?? APB ???
//
// ==========================================

class debug_dap_apb_access_sequence extends uvm_sequence#(svt_jtag_transaction);

  `uvm_object_utils(debug_dap_apb_access_sequence)
  `uvm_declare_p_sequencer(svt_jtag_transaction_sequencer)

  // ==========================================
  // ????? - ????????!?
  // ==========================================

  // APB ????: 1=?, 0=?
  rand bit is_write;

  // APB ???? (32?????!)
  // ????????? ADDR[3:2] ? DAP
  rand bit [31:0] apb_addr;

  // APB ??? (??????)
  rand bit [31:0] write_data;

  // APB ??? (??????, ???? APB ????????)
  bit [31:0] read_data;

  // ==========================================
  // DAP ???? (????)
  // ==========================================

  // JTAG-DP IR ??
  localparam IR_DPACC  = 4'b1010;  // DP ??
  localparam IR_APACC  = 4'b1011;  // AP ?? - ????? APB ??!

  // DP ?????
  localparam DP_RDBUFF = 2'b11;    // ?????? - ???? AP ???

  function new(string name = "debug_dap_apb_access_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_jtag_transaction tr;
    svt_jtag_transaction rsp;
    bit [34:0] dr_tx_data;
    bit [34:0] dr_rx_data;
    bit [1:0] dp_reg_addr;

    `uvm_info("DAP_APB", $sformatf("?? APB ??: %s ADDR=0x%08h",
      is_write ? "?" : "?", apb_addr), UVM_LOW)

    // ? APB ???? DAP ??? ADDR[3:2]
    // ARM DAP ?????? AP ????????
    dp_reg_addr = apb_addr[3:2];

    // ==========================================
    // Step 1: ?? TAP ???
    // ==========================================
    `uvm_info("DAP_APB", "Step 1: TAP ??", UVM_HIGH)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RESET_STATE;
    tr.num_tck_cycles = 5;
    `uvm_send(tr)

    // ==========================================
    // Step 2: Shift-IR ?? APACC
    // ==========================================
    // APACC ???? DAP: ???? DR ????? APB ??!
    `uvm_info("DAP_APB", "Step 2: Shift-IR (APACC) - ?? AP ????", UVM_HIGH)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_IR_STATE;
    `uvm_send(tr)

    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_IR;
    tr.data_width = 4;
    tr.tx_data = new[1];
    tr.tx_data[0] = IR_APACC;
    tr.num_tck_cycles = 4;
    `uvm_send(tr)
    get_response(rsp)

    // ==========================================
    // Step 3: Shift-DR ?? APB ??
    // ==========================================
    `uvm_info("DAP_APB", "Step 3: Shift-DR - ?? APB ??", UVM_HIGH)

    // ?? Shift-DR ??
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
    `uvm_send(tr)

    // ?? 35 ? DR ??
    // Bit 34:    WnR (1=?, 0=?)
    // Bits 33-2: ?? (?: ?????, ?: ??)
    // Bits 1-0:  ACK (??)
    dr_tx_data[34]    = is_write;               // ????
    dr_tx_data[33:2]  = is_write ? write_data : 32'h0;  // ???
    dr_tx_data[1:0]   = 2'b00;                  // ACK ?

    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR;
    tr.data_width = 35;
    tr.tx_data = new[1];
    tr.tx_data[0] = dr_tx_data;
    tr.num_tck_cycles = 35;
    `uvm_send(tr)
    get_response(rsp)

    dr_rx_data = rsp.rx_data[0][34:0];

    `uvm_info("DAP_APB", $sformatf("APB ?????! ACK=%2b", dr_rx_data[1:0]), UVM_HIGH)

    // ==========================================
    // Step 4: ???????? RDBUFF ???
    // ==========================================
    if (!is_write) begin
      `uvm_info("DAP_APB", "Step 4: ??? - ? RDBUFF ?? APB ??", UVM_HIGH)

      // ??? DPACC ?? - ?? DP ? RDBUFF ???
      `uvm_create(tr)
      tr.opcode = svt_jtag_types::SHIFT_IR_STATE;
      `uvm_send(tr)

      `uvm_create(tr)
      tr.opcode = svt_jtag_types::SHIFT_IR;
      tr.data_width = 4;
      tr.tx_data = new[1];
      tr.tx_data[0] = IR_DPACC;
      tr.num_tck_cycles = 4;
      `uvm_send(tr)
      get_response(rsp)

      // Shift-DR ? RDBUFF
      `uvm_create(tr)
      tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
      `uvm_send(tr)

      // ???: WnR=0, ?????
      dr_tx_data[34]    = 1'b0;
      dr_tx_data[33:2]  = 32'h0;
      dr_tx_data[1:0]   = 2'b00;

      `uvm_create(tr)
      tr.opcode = svt_jtag_types::SHIFT_DR;
      tr.data_width = 35;
      tr.tx_data = new[1];
      tr.tx_data[0] = dr_tx_data;
      tr.num_tck_cycles = 35;
      `uvm_send(tr)
      get_response(rsp)

      dr_rx_data = rsp.rx_data[0][34:0];

      // ????? APB ??!
      read_data = dr_rx_data[33:2];

      `uvm_info("DAP_APB", $sformatf("APB ???: 0x%08h", read_data), UVM_LOW)
    end else begin
      `uvm_info("DAP_APB", $sformatf("APB ???: DATA=0x%08h", write_data), UVM_LOW)
    end

    // ==========================================
    // Step 5: ?? Run-Test-Idle
    // ==========================================
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RUN_TEST_IDLE_STATE;
    tr.num_tck_cycles = 10;
    `uvm_send(tr)

    `uvm_info("DAP_APB", "APB ??????!", UVM_HIGH)
  endtask

endclass

`endif
