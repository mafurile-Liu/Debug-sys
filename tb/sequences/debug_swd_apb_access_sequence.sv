`ifndef DEBUG_SWD_APB_ACCESS_SEQUENCE_SV
`define DEBUG_SWD_APB_ACCESS_SEQUENCE_SV

// ==========================================
// SWD-to-APB ???????
// ==========================================
// ?????? JTAG ??????!?
//
// ??:
//   is_write   - 1=APB?, 0=APB?
//   apb_addr   - 32? APB ????
//   write_data - 32???? (??????)
//
// ??:
//   read_data  - 32????
//
// ?SVT SWD VIP ??? DAP ???
//   VIP ??? 4 ?????????? SWD ?????:
//     - DEBUG_PORT_WRITE / DEBUG_PORT_READ  (DP ?????)
//     - ACCESS_PORT_WRITE / ACCESS_PORT_READ (AP ?? - ?? APB ??!)
//     - LINE_RESET (???)
//
//   ???:
//     1. LINE_RESET
//     2. ACCESS_PORT_WRITE ? VIP ??? SWD ???? ? DUT ?? APB ?
//
//   ???:
//     1. LINE_RESET
//     2. ACCESS_PORT_READ  ? VIP ??? SWD ???? ? DUT ?? APB ?
//     3. DEBUG_PORT_READ (RDBUFF) ? ? DP ? RDBUFF ????? APB ??
//
// ==========================================

class debug_swd_apb_access_sequence extends uvm_sequence#(svt_swd_transaction);

  `uvm_object_utils(debug_swd_apb_access_sequence)
  `uvm_declare_p_sequencer(svt_swd_transaction_sequencer)

  // ==========================================
  // ????? - ? JTAG ??????!?
  // ==========================================

  // APB ????: 1=?, 0=?
  rand bit is_write;

  // APB ???? (32?????!)
  rand bit [31:0] apb_addr;

  // APB ??? (??????)
  rand bit [31:0] write_data;

  // APB ??? (????????)
  bit [31:0] read_data;

  // ==========================================
  // ????
  // ==========================================
  svt_swd_transaction rsp;

  // DP ????? (A[3:2])
  localparam DP_RDBUFF = 2'b11;  // ??????

  function new(string name = "debug_swd_apb_access_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_swd_transaction tr;
    bit [1:0] swd_addr;

    `uvm_info("SWD_APB", $sformatf("?? SWD APB ??: %s ADDR=0x%08h",
      is_write ? "?" : "?", apb_addr), UVM_LOW)

    // ? APB ???? SWD ??? A[3:2]
    swd_addr = apb_addr[3:2];

    // ==========================================
    // Step 1: SWD ???
    // ==========================================
    `uvm_info("SWD_APB", "Step 1: SWD ???", UVM_HIGH)
    `uvm_create(tr)
    tr.cmd_type = svt_swd_types::LINE_RESET;
    `uvm_send(tr)
    get_response(rsp)

    // ==========================================
    // Step 2: ?? AP ???? (?? APB ??!)
    // ==========================================
    // ACCESS_PORT ???? VIP ??????? SWD AP ???,
    // DUT ?? DAP ?????? APB ????
    `uvm_info("SWD_APB", "Step 2: ?? AP ???? (?? APB ??)", UVM_HIGH)

    `uvm_create(tr)
    tr.addr = swd_addr;           // A[3:2] ?? APB ??
    tr.data = write_data;         // ??? (??????)

    if (is_write) begin
      tr.cmd_type = svt_swd_types::ACCESS_PORT_WRITE;
    end else begin
      tr.cmd_type = svt_swd_types::ACCESS_PORT_READ;
    end

    `uvm_send(tr)
    get_response(rsp)

    `uvm_info("SWD_APB", $sformatf("APB ?????! ACK=%s", rsp.ack_type.name()), UVM_HIGH)

    // ==========================================
    // Step 3: ???????? RDBUFF ???
    // ==========================================
    if (!is_write) begin
      `uvm_info("SWD_APB", "Step 3: ??? - ? RDBUFF ?? APB ??", UVM_HIGH)

      // ? DP ? RDBUFF ??? (addr = 2'b11)
      // ??: AP ??????? DAP ? RDBUFF ?, ?????? DP ????
      `uvm_create(tr)
      tr.cmd_type = svt_swd_types::DEBUG_PORT_READ;
      tr.addr = DP_RDBUFF;         // RDBUFF ?????
      `uvm_send(tr)
      get_response(rsp)

      // ????? APB ??!
      read_data = rsp.data;

      `uvm_info("SWD_APB", $sformatf("APB ???: 0x%08h", read_data), UVM_LOW)
    end else begin
      `uvm_info("SWD_APB", $sformatf("APB ???: DATA=0x%08h", write_data), UVM_LOW)
    end

    `uvm_info("SWD_APB", "APB ??????!", UVM_HIGH)
  endtask

endclass

`endif
