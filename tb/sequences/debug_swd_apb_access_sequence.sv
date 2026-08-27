`ifndef DEBUG_SWD_APB_ACCESS_SEQUENCE_SV
`define DEBUG_SWD_APB_ACCESS_SEQUENCE_SV

// ==========================================
// SWD-to-APB 一站式访问序列
// ==========================================
// 【用户接口和 JTAG 版本完全一样!】
//
// 输入:
//   is_write   - 1=APB写, 0=APB读
//   apb_addr   - 32位 APB 总线地址
//   write_data - 32位写数据 (写操作时有效)
//
// 输出:
//   read_data  - 32位读结果
//
// 【SVT SWD VIP 已封装 DAP 协议】
//   VIP 提供了 4 种命令类型，自动处理 SWD 数据包格式:
//     - DEBUG_PORT_WRITE / DEBUG_PORT_READ  (DP 寄存器访问)
//     - ACCESS_PORT_WRITE / ACCESS_PORT_READ (AP 访问 - 产生 APB 事务!)
//     - LINE_RESET (线复位)
//
//   写操作:
//     1. LINE_RESET
//     2. ACCESS_PORT_WRITE → VIP 自动发 SWD 写请求包 → DUT 产生 APB 写
//
//   读操作:
//     1. LINE_RESET
//     2. ACCESS_PORT_READ  → VIP 自动发 SWD 读请求包 → DUT 产生 APB 读
//     3. DEBUG_PORT_READ (RDBUFF) → 读 DP 的 RDBUFF 寄存器得到 APB 数据
//
// ==========================================

class debug_swd_apb_access_sequence extends uvm_sequence#(svt_swd_transaction);

  `uvm_object_utils(debug_swd_apb_access_sequence)
  `uvm_declare_p_sequencer(svt_swd_transaction_sequencer)

  // ==========================================
  // 【用户接口 - 和 JTAG 版本完全一致!】
  // ==========================================

  // APB 传输方向: 1=写, 0=读
  rand bit is_write;

  // APB 总线地址 (32位完整地址!)
  rand bit [31:0] apb_addr;

  // APB 写数据 (写操作时设置)
  rand bit [31:0] write_data;

  // APB 读结果 (读操作完成后有效)
  bit [31:0] read_data;

  // ==========================================
  // 内部变量
  // ==========================================
  svt_swd_transaction rsp;

  // DP 寄存器地址 (A[3:2])
  localparam DP_RDBUFF = 2'b11;  // 读缓冲寄存器

  function new(string name = "debug_swd_apb_access_sequence");
    super.new(name);
  endfunction

  virtual task body();
    svt_swd_transaction tr;
    bit [1:0] swd_addr;

    `uvm_info("SWD_APB", $sformatf("开始 SWD APB 访问: %s ADDR=0x%08h",
      is_write ? "写" : "读", apb_addr), UVM_LOW)

    // 从 APB 地址提取 SWD 需要的 A[3:2]
    swd_addr = apb_addr[3:2];

    // ==========================================
    // Step 1: SWD 线复位
    // ==========================================
    `uvm_info("SWD_APB", "Step 1: SWD 线复位", UVM_HIGH)
    `uvm_create(tr)
    tr.cmd_type = svt_swd_types::LINE_RESET;
    `uvm_send(tr)
    get_response(rsp)

    // ==========================================
    // Step 2: 发送 AP 访问请求 (产生 APB 事务!)
    // ==========================================
    // ACCESS_PORT 命令会让 VIP 自动发送完整的 SWD AP 访问包,
    // DUT 侧的 DAP 会把它转换成 APB 总线事务
    `uvm_info("SWD_APB", "Step 2: 发送 AP 访问请求 (产生 APB 事务)", UVM_HIGH)

    `uvm_create(tr)
    tr.addr = swd_addr;           // A[3:2] 来自 APB 地址
    tr.data = write_data;         // 写数据 (读操作时忽略)

    if (is_write) begin
      tr.cmd_type = svt_swd_types::ACCESS_PORT_WRITE;
    end else begin
      tr.cmd_type = svt_swd_types::ACCESS_PORT_READ;
    end

    `uvm_send(tr)
    get_response(rsp)

    `uvm_info("SWD_APB", $sformatf("APB 事务已发出! ACK=%s", rsp.ack_type.name()), UVM_HIGH)

    // ==========================================
    // Step 3: 读操作需要额外读 RDBUFF 寄存器
    // ==========================================
    if (!is_write) begin
      `uvm_info("SWD_APB", "Step 3: 读操作 - 从 RDBUFF 读取 APB 结果", UVM_HIGH)

      // 读 DP 的 RDBUFF 寄存器 (addr = 2'b11)
      // 注意: AP 读的数据先存在 DAP 的 RDBUFF 里, 需要再读一次 DP 才能拿到
      `uvm_create(tr)
      tr.cmd_type = svt_swd_types::DEBUG_PORT_READ;
      tr.addr = DP_RDBUFF;         // RDBUFF 寄存器地址
      `uvm_send(tr)
      get_response(rsp)

      // 提取读到的 APB 数据!
      read_data = rsp.data;

      `uvm_info("SWD_APB", $sformatf("APB 读结果: 0x%08h", read_data), UVM_LOW)
    end else begin
      `uvm_info("SWD_APB", $sformatf("APB 写完成: DATA=0x%08h", write_data), UVM_LOW)
    end

    `uvm_info("SWD_APB", "APB 访问序列完成!", UVM_HIGH)
  endtask

endclass

`endif
