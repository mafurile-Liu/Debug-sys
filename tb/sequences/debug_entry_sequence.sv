`ifndef DEBUG_ENTRY_SEQUENCE_SV
`define DEBUG_ENTRY_SEQUENCE_SV

`ifdef DEBUG_PORT_JTAG
class debug_entry_sequence extends uvm_sequence #(svt_jtag_transaction);
  `uvm_object_utils(debug_entry_sequence)
  `uvm_declare_p_sequencer(svt_jtag_transaction_sequencer)

  function new(string name = "debug_entry_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_jtag_transaction item;

    item = svt_jtag_transaction::type_id::create("load_idcode_ir");
    start_item(item);
    item.cmd_type = svt_jtag_types::IR;
    item.enable_cmd_tdi = 1'b1;
    item.cmd_ir_tdi = 8'h06;
    item.cnt_idle = 3;
    finish_item(item);

    item = svt_jtag_transaction::type_id::create("read_idcode_dr");
    start_item(item);
    item.cmd_type = svt_jtag_types::DR;
    item.enable_cmd_tdi = 1'b1;
    item.cmd_length = 32;
    item.cmd_dr_tdi = '0;
    item.cnt_idle = 3;
    finish_item(item);
  endtask
endclass
`elsif DEBUG_PORT_SWD
class debug_entry_sequence extends uvm_sequence #(svt_swd_transaction);
  `uvm_object_utils(debug_entry_sequence)
  `uvm_declare_p_sequencer(svt_swd_transaction_sequencer)

  function new(string name = "debug_entry_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_swd_transaction item;

    item = svt_swd_transaction::type_id::create("line_reset");
    start_item(item);
    item.cmd_type = svt_swd_types::LINE_RESET;
    item.addr = 2'b00;
    item.data = '0;
    finish_item(item);

    item = svt_swd_transaction::type_id::create("read_dpidr");
    start_item(item);
    item.cmd_type = svt_swd_types::DEBUG_PORT_READ;
    item.addr = 2'b00;
    item.data = '0;
    finish_item(item);
  endtask
endclass
`endif

`endif

