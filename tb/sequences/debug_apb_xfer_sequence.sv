`ifndef DEBUG_APB_XFER_SEQUENCE_SV
`define DEBUG_APB_XFER_SEQUENCE_SV

// !! DEPRECATED !!
//
// This sequence directly constructs APB transactions,
// which violates the AI_DESIGN_GUIDE architecture principle:
//   Test -> Sequence -> RAL -> Adapter -> Agent
//
// Please use the RAL-based sequences instead:
//   - debug_apb_reg_sequence.sv (Protocol layer)
//   - debug_apb_reg_test_sequence.sv (Feature layer)
//   - debug_apb_scenario_sequence.sv (Scenario layer)
//
// This file is kept for backwards compatibility only.
class debug_apb_xfer_sequence extends svt_apb_master_base_sequence;

  rand int unsigned sequence_length = 8;
  constraint c_len { sequence_length <= 100; }

  `uvm_object_utils(debug_apb_xfer_sequence)

  function new(string name = "debug_apb_xfer_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_apb_master_transaction wr_tr, rd_tr;
    `uvm_info("APB_XFER", "APB transfer sequence (DEPRECATED - use RAL-based)", UVM_LOW)
    super.body();

    for (int i = 0; i < sequence_length; i++) begin
      `uvm_create(wr_tr)
      wr_tr.cfg       = cfg;
      wr_tr.xact_type = svt_apb_transaction::WRITE;
      wr_tr.addr      = 16'h0100 * i;
      wr_tr.data      = 32'hDEADBEEF ^ (i * 32'h01010101);
      wr_tr.num_wait_cycles = 3;
      `uvm_send(wr_tr)
      get_response(rsp);

      `uvm_create(rd_tr)
      rd_tr.cfg       = cfg;
      rd_tr.xact_type = svt_apb_transaction::READ;
      rd_tr.addr      = wr_tr.addr;
      `uvm_send(rd_tr)
      get_response(rsp);

      if (rsp.read_data !== wr_tr.data)
        `uvm_error("APB_DATA_MISMATCH", $sformatf(
          "addr=0x%0h wrote=0x%0h read=0x%0h",
          wr_tr.addr, wr_tr.data, rsp.read_data))
    end

    `uvm_info("APB_XFER", "APB transfer sequence done", UVM_LOW)
  endtask
endclass

`endif