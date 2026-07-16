`ifndef DEBUG_APB_XFER_SEQUENCE_SV
`define DEBUG_APB_XFER_SEQUENCE_SV

/**
 * APB master 收发验证序列
 *
 * 通过 apb_master_env.master.sequencer 发送 WRITE + READ-BACK 事务对，
 * 数据经 debug_apb_loopback 到达 apb_slave_env (svt_apb_slave_memory_sequence
 * 自动响应)，debug_sys_scoreboard 独立比对 master/slave 两端观测。
 */
class debug_apb_xfer_sequence extends svt_apb_master_base_sequence;

  rand int unsigned sequence_length = 8;
  constraint c_len { sequence_length <= 100; }

  `uvm_object_utils(debug_apb_xfer_sequence)

  function new(string name = "debug_apb_xfer_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_apb_master_transaction wr_tr, rd_tr;
    `uvm_info("APB_XFER", "APB transfer sequence started", UVM_LOW)
    super.body();

    for (int i = 0; i < sequence_length; i++) begin
      // ── WRITE ──
      `uvm_create(wr_tr)
      wr_tr.cfg       = cfg;
      wr_tr.xact_type = svt_apb_transaction::WRITE;
      wr_tr.addr      = 16'h0100 * i;
      wr_tr.data      = 32'hDEAD_BEEF ^ (i * 32'h0101_0101);
      wr_tr.num_wait_cycles = 3;
      `uvm_send(wr_tr)
      get_response(rsp);
      `uvm_info("APB_XFER", $sformatf(
        "WR #%0d addr=0x%0h data=0x%0h", i, wr_tr.addr, wr_tr.data), UVM_LOW)

      // ── READ-BACK ──
      `uvm_create(rd_tr)
      rd_tr.cfg       = cfg;
      rd_tr.xact_type = svt_apb_transaction::READ;
      rd_tr.addr      = wr_tr.addr;
      `uvm_send(rd_tr)
      get_response(rsp);
      `uvm_info("APB_XFER", $sformatf(
        "RD #%0d addr=0x%0h rdata=0x%0h", i, rd_tr.addr, rsp.read_data), UVM_LOW)

      // ── 验证读回数据 ──
      if (rsp.read_data !== wr_tr.data)
        `uvm_error("APB_DATA_MISMATCH", $sformatf(
          "addr=0x%0h wrote=0x%0h read=0x%0h",
          wr_tr.addr, wr_tr.data, rsp.read_data))
      else
        `uvm_info("APB_DATA_MATCH", $sformatf(
          "addr=0x%0h data=0x%0h verified OK",
          wr_tr.addr, wr_tr.data), UVM_LOW)
    end

    `uvm_info("APB_XFER", "APB transfer sequence done", UVM_LOW)
  endtask
endclass

`endif