`ifndef DEBUG_SWD_APB_ACCESS_TEST_SV
`define DEBUG_SWD_APB_ACCESS_TEST_SV

// ==========================================
// SWD-to-APB 一站式访问测试
// ==========================================
// 【用户接口和 JTAG 版本完全一样!】
//
// 你只需要设置:
//   seq.is_write    = 1'b1;  // 1=写, 0=读
//   seq.apb_addr    = 32'hxxxx_xxxx;  // APB 总线地址
//   seq.write_data  = 32'hxxxx_xxxx;  // 要写的数据
//
// 然后调用一次 seq.start() 就搞定了!
//
// 读操作完成后:
//   read_result = seq.read_data;  // 就是 APB 总线上读到的数据
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
    `uvm_info("TEST", "START: SWD-APB 一站式访问测试", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // 示例 1: APB 写操作
    // ==========================================
    `uvm_info("TEST", "----- 示例 1: APB 写操作 -----", UVM_LOW)
    `uvm_info("TEST", "【和 JTAG 接口一模一样!】", UVM_MEDIUM)

    swd_seq = debug_swd_apb_access_sequence::type_id::create("swd_write_seq");

    // 【你只需要设置这 3 个!】
    swd_seq.is_write    = 1'b1;               // 写操作
    swd_seq.apb_addr    = 32'h4000_0000;       // APB 总线地址
    swd_seq.write_data  = 32'hCAFE_BABE;       // 要写的数据

    // 【一次调用就完成! SWD 自动产生 APB 事务】
    swd_seq.start(env.vseqr.swd_sequencer);

    `uvm_info("TEST", $sformatf("APB 写完成: ADDR=0x%08h DATA=0x%08h",
      swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // 示例 2: APB 读操作
    // ==========================================
    `uvm_info("TEST", "----- 示例 2: APB 读操作 -----", UVM_LOW)
    `uvm_info("TEST", "【和 JTAG 接口一模一样!】", UVM_MEDIUM)

    swd_seq = debug_swd_apb_access_sequence::type_id::create("swd_read_seq");

    // 【你只需要设置这 2 个!】
    swd_seq.is_write    = 1'b0;               // 读操作
    swd_seq.apb_addr    = 32'h4000_0004;       // APB 总线地址

    // 【一次调用就完成!】
    swd_seq.start(env.vseqr.swd_sequencer);

    // 【结果在这里!】
    read_result = swd_seq.read_data;

    `uvm_info("TEST", $sformatf("APB 读完成: ADDR=0x%08h DATA=0x%08h",
      swd_seq.apb_addr, read_result), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)

    // ==========================================
    // 示例 3: 连续的 APB 读写
    // ==========================================
    `uvm_info("TEST", "----- 示例 3: 连续 APB 读写 -----", UVM_LOW)

    // 写地址 0
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq1");
    swd_seq.is_write = 1'b1;
    swd_seq.apb_addr = 32'h4000_0000;
    swd_seq.write_data = 32'hAAAA_AAAA;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("写 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    // 写地址 4
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq2");
    swd_seq.is_write = 1'b1;
    swd_seq.apb_addr = 32'h4000_0004;
    swd_seq.write_data = 32'hBBBB_BBBB;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("写 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.write_data), UVM_LOW)

    // 读地址 0
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq3");
    swd_seq.is_write = 1'b0;
    swd_seq.apb_addr = 32'h4000_0000;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("读 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.read_data), UVM_LOW)

    // 读地址 4
    swd_seq = debug_swd_apb_access_sequence::type_id::create("seq4");
    swd_seq.is_write = 1'b0;
    swd_seq.apb_addr = 32'h4000_0004;
    swd_seq.start(env.vseqr.swd_sequencer);
    `uvm_info("TEST", $sformatf("读 0x%08h: 0x%08h", swd_seq.apb_addr, swd_seq.read_data), UVM_LOW)

    `uvm_info("TEST", "", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "END: SWD-APB 一站式访问测试", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
