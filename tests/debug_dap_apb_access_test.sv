`ifndef DEBUG_DAP_APB_ACCESS_TEST_SV
`define DEBUG_DAP_APB_ACCESS_TEST_SV

// ==========================================
// DAP-APB ???????
// ==========================================
// ???????!?
//
// ??????:
//   seq.is_write    = 1'b1;  // 1=?, 0=?
//   seq.apb_addr    = 32'hxxxx_xxxx;  // APB ????
//   seq.write_data  = 32'hxxxx_xxxx;  // ?????
//
// ?????? seq.start() ????!
//
// ??????:
//   read_result = seq.read_data;  // ?? APB ????????
//
// ==========================================

class debug_dap_apb_access_test extends debug_port_base_test;

  `uvm_component_utils(debug_dap_apb_access_test)

  function new(string name = "debug_dap_apb_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    debug_dap_apb_access_sequence dap_seq;
    bit [31:0] read_result;

    phase.raise_objection(this);
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "START: DAP-APB ???????", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 1: APB ???
    // ==========================================
    `uvm_info("TEST", "----- ?? 1: APB ??? -----", UVM_LOW)
    `uvm_info("TEST", "?? 3 ??????!", UVM_MEDIUM)

    dap_seq = debug_dap_apb_access_sequence::type_id::create("dap_write_seq");

    // ???????? 3 ?!?
    dap_seq.is_write    = 1'b1;               // ???
    dap_seq.apb_addr    = 32'h4000_0000;       // APB ????
    dap_seq.write_data  = 32'hDEAD_BEEF;       // ?????

    // ????????!?
    dap_seq.start(env.vseqr.jtag_sequencer);

    `uvm_info("TEST", $sformatf("APB ???: ADDR=0x%08h DATA=0x%08h",
      dap_seq.apb_addr, dap_seq.write_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 2: APB ???
    // ==========================================
    `uvm_info("TEST", "----- ?? 2: APB ??? -----", UVM_LOW)
    `uvm_info("TEST", "?? 2 ???, ?????!", UVM_MEDIUM)

    dap_seq = debug_dap_apb_access_sequence::type_id::create("dap_read_seq");

    // ???????? 2 ?!?
    dap_seq.is_write    = 1'b0;               // ???
    dap_seq.apb_addr    = 32'h4000_0004;       // APB ????

    // ????????!?
    dap_seq.start(env.vseqr.jtag_sequencer);

    // ??????!?
    read_result = dap_seq.read_data;

    `uvm_info("TEST", $sformatf("APB ???: ADDR=0x%08h DATA=0x%08h",
      dap_seq.apb_addr, read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 3: ??? APB ??
    // ==========================================
    `uvm_info("TEST", "----- ?? 3: ?? APB ?? -----", UVM_LOW)

    // ??? 0
    dap_seq = debug_dap_apb_access_sequence::type_id::create("seq1");
    dap_seq.is_write = 1'b1;
    dap_seq.apb_addr = 32'h4000_0000;
    dap_seq.write_data = 32'h1111_1111;
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", dap_seq.apb_addr, dap_seq.write_data), UVM_LOW)

    // ??? 4
    dap_seq = debug_dap_apb_access_sequence::type_id::create("seq2");
    dap_seq.is_write = 1'b1;
    dap_seq.apb_addr = 32'h4000_0004;
    dap_seq.write_data = 32'h2222_2222;
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", dap_seq.apb_addr, dap_seq.write_data), UVM_LOW)

    // ??? 0
    dap_seq = debug_dap_apb_access_sequence::type_id::create("seq3");
    dap_seq.is_write = 1'b0;
    dap_seq.apb_addr = 32'h4000_0000;
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", dap_seq.apb_addr, dap_seq.read_data), UVM_LOW)

    // ??? 4
    dap_seq = debug_dap_apb_access_sequence::type_id::create("seq4");
    dap_seq.is_write = 1'b0;
    dap_seq.apb_addr = 32'h4000_0004;
    dap_seq.start(env.vseqr.jtag_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", dap_seq.apb_addr, dap_seq.read_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "END: DAP-APB ???????", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
