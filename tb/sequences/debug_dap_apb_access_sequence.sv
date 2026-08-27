`ifndef DEBUG_DAP_APB_ACCESS_SEQUENCE_SV
`define DEBUG_DAP_APB_ACCESS_SEQUENCE_SV

// ==========================================
// DAP-to-APB 一站式访问序列
// ==========================================
// 【你只需要关心这 4 个变量！】
//
// 输入:
//   is_write   - 1=APB写, 0=APB读
//   apb_addr   - 32位 APB 总线地址 (不是DP寄存器地址!)
//   write_data - 32位写数据 (写操作时有效)
//
// 输出:
//   read_data  - 32位读结果 (读操作完成后有效)
//
// 【调用一次就完成完整 APB 事务!】
//
// 内部自动完成的 ARM DAP 协议流程:
//   写操作:
//     1. SHIFT-IR(APACC) → SHIFT-DR[WnR=1, ADDR[3:2], DATA]
//        → 产生 APB 写事务
//
//   读操作:
//     1. SHIFT-IR(APACC) → SHIFT-DR[WnR=0, ADDR[3:2]]
//        → 产生 APB 读事务, 数据存入 RDBUFF
//     2. SHIFT-IR(DPACC) → SHIFT-DR 读 RDBUFF 寄存器
//        → 得到 APB 读数据
//
// ==========================================

class debug_dap_apb_access_sequence extends uvm_sequence#(svt_jtag_transaction);

  `uvm_object_utils(debug_dap_apb_access_sequence)
  `uvm_declare_p_sequencer(svt_jtag_transaction_sequencer)

  // ==========================================
  // 【用户接口 - 你只需要设置这些!】
  // ==========================================

  // APB 传输方向: 1=写, 0=读
  rand bit is_write;

  // APB 总线地址 (32位完整地址!)
  // 序列内部会自动提取 ADDR[3:2] 给 DAP
  rand bit [31:0] apb_addr;

  // APB 写数据 (写操作时设置)
  rand bit [31:0] write_data;

  // APB 读结果 (读操作完成后, 这里就是 APB 总线上读到的数据)
  bit [31:0] read_data;

  // ==========================================
  // DAP 协议常数 (内部使用)
  // ==========================================

  // JTAG-DP IR 指令
  localparam IR_DPACC  = 4'b1010;  // DP 访问
  localparam IR_APACC  = 4'b1011;  // AP 访问 - 这个会产生 APB 事务!

  // DP 寄存器地址
  localparam DP_RDBUFF = 2'b11;    // 读缓冲寄存器 - 存上一次 AP 读结果

  function new(string name = "debug_dap_apb_access_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_jtag_transaction tr;
    svt_jtag_transaction rsp;
    bit [34:0] dr_tx_data;
    bit [34:0] dr_rx_data;
    bit [1:0] dp_reg_addr;

    `uvm_info("DAP_APB", $sformatf("开始 APB 访问: %s ADDR=0x%08h",
      is_write ? "写" : "读", apb_addr), UVM_LOW)

    // 从 APB 地址提取 DAP 需要的 ADDR[3:2]
    // ARM DAP 用这两位作为 AP 内部的寄存器选择
    dp_reg_addr = apb_addr[3:2];

    // ==========================================
    // Step 1: 复位 TAP 状态机
    // ==========================================
    `uvm_info("DAP_APB", "Step 1: TAP 复位", UVM_HIGH)
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RESET_STATE;
    tr.num_tck_cycles = 5;
    `uvm_send(tr)

    // ==========================================
    // Step 2: Shift-IR 选择 APACC
    // ==========================================
    // APACC 指令告诉 DAP: 接下来的 DR 操作要转成 APB 事务!
    `uvm_info("DAP_APB", "Step 2: Shift-IR (APACC) - 启动 AP 访问模式", UVM_HIGH)
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
    // Step 3: Shift-DR 执行 APB 事务
    // ==========================================
    `uvm_info("DAP_APB", "Step 3: Shift-DR - 产生 APB 事务", UVM_HIGH)

    // 进入 Shift-DR 状态
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
    `uvm_send(tr)

    // 构造 35 位 DR 数据
    // Bit 34:    WnR (1=写, 0=读)
    // Bits 33-2: 数据 (写: 要写的数据, 读: 忽略)
    // Bits 1-0:  ACK (响应)
    dr_tx_data[34]    = is_write;               // 读还是写
    dr_tx_data[33:2]  = is_write ? write_data : 32'h0;  // 写数据
    dr_tx_data[1:0]   = 2'b00;                  // ACK 位

    `uvm_create(tr)
    tr.opcode = svt_jtag_types::SHIFT_DR;
    tr.data_width = 35;
    tr.tx_data = new[1];
    tr.tx_data[0] = dr_tx_data;
    tr.num_tck_cycles = 35;
    `uvm_send(tr)
    get_response(rsp)

    dr_rx_data = rsp.rx_data[0][34:0];

    `uvm_info("DAP_APB", $sformatf("APB 事务已发出! ACK=%2b", dr_rx_data[1:0]), UVM_HIGH)

    // ==========================================
    // Step 4: 读操作需要额外读 RDBUFF 寄存器
    // ==========================================
    if (!is_write) begin
      `uvm_info("DAP_APB", "Step 4: 读操作 - 从 RDBUFF 读取 APB 结果", UVM_HIGH)

      // 切换回 DPACC 指令 - 要读 DP 的 RDBUFF 寄存器
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

      // Shift-DR 读 RDBUFF
      `uvm_create(tr)
      tr.opcode = svt_jtag_types::SHIFT_DR_STATE;
      `uvm_send(tr)

      // 读操作: WnR=0, 数据域忽略
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

      // 提取读到的 APB 数据!
      read_data = dr_rx_data[33:2];

      `uvm_info("DAP_APB", $sformatf("APB 读结果: 0x%08h", read_data), UVM_LOW)
    end else begin
      `uvm_info("DAP_APB", $sformatf("APB 写完成: DATA=0x%08h", write_data), UVM_LOW)
    end

    // ==========================================
    // Step 5: 回到 Run-Test-Idle
    // ==========================================
    `uvm_create(tr)
    tr.opcode = svt_jtag_types::RUN_TEST_IDLE_STATE;
    tr.num_tck_cycles = 10;
    `uvm_send(tr)

    `uvm_info("DAP_APB", "APB 访问序列完成!", UVM_HIGH)
  endtask

endclass

`endif
