`ifndef DEBUG_SWD_APB_ACCESS_TEST_SV
`define DEBUG_SWD_APB_ACCESS_TEST_SV

// ==========================================
// SWD-to-APB ???????
// ==========================================
// ?????? JTAG ??????!?
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

class debug_swd_apb_access_test extends debug_port_base_test;

  `uvm_component_utils(debug_swd_apb_access_test)

  function new(string name = "debug_swd_apb_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    debug_swd_apb_access_sequence swd_seq;
    bit [31:0] read_result;

    phase.raise_objection(this);
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "START: SWD-APB ???????", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 1: APB ???
    // ==========================================
    `uvm_info("TEST", "----- ?? 1: APB ??? -----", UVM_LOW)
    `uvm_info("TEST", "?? JTAG ??????!?", UVM_MEDIUM)

    swd_seq = debug_swd_apb_access_sequence::type_id::create("swd_write_seq");

    // ???????? 3 ?!?
    swd_seq.is_write    = 1'b1;               // ???
    swd_seq.apb_addr    = 32'h4000_0000;       // APB ????
    swd_seq.write_data  = 32'hCAFE_BABE;       // ?????

    // ????????! SWD ???? APB ???
    swd_seq.start(env.vseqr.swd_sequencer);

    `uvm_info("TEST", $sformatf("APB ???: ADDR=0x%08h DATA=0x%08h",
      swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 2: APB ???
    // ==========================================
    `uvm_info("TEST", "----- ?? 2: APB ??? -----", UVM_LOW)
    `uvm_info("TEST", "?? JTAG ??????!?", UVM_MEDIUM)

    swd_seq = debug_swd_apb_access_sequence::type_id::create("swd_read_seq");

    // ???????? 2 ?!?
    swd_seq.is_write    = 1'b0;               // ???
    swd_seq.apb_addr    = 32'h4000_0004;       // APB ????

    // ????????!?
    swd_seq.start(env.vseqr.swd_sequencer);

    // ??????!?
    read_result = swd_seq.read_data;

    `uvm_info("TEST", $sformatf("APB ???: ADDR=0x%08h DATA=0x%08h",
      swd_seq.apb_addr, read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // ?? 3: ??? APB ??
    // ==========================================
    `uvm_info("TEST", "----- ?? 3: ?? APB ?? -----", UVM_LOW)

    // ??? 0
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq1");
    swd_seq.is_write = 1'b1;
    swd_seq.apb_addr = 32'h4000_0000;
    swd_seq.write_data = 32'hAAAA_AAAA;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    // ??? 4
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq2");
    swd_seq.is_write = 1'b1;
    swd_seq.apb_addr = 32'h4000_0004;
    swd_seq.write_data = 32'hBBBB_BBBB;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    // ??? 0
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq3");
    swd_seq.is_write = 1'b0;
    swd_seq.apb_addr = 32'h4000_0000;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.read_data), UVM_LOW)

    // ??? 4
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq4");
    swd_seq.is_write = 1'b0;
    swd_seq.apb_addr = 32'h4000_0004;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("? 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.read_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "END: SWD-APB ???????", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
