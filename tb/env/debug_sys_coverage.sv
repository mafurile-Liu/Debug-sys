`ifndef DEBUG_SYS_COVERAGE_SV
`define DEBUG_SYS_COVERAGE_SV

// APB Register Coverage Collector
// SEPARATE from Scoreboard (Single Responsibility Principle)
class debug_sys_coverage extends uvm_subscriber#(svt_apb_transaction);

  `uvm_component_utils(debug_sys_coverage)

  //-------------------------------------------
  // Covergroups - instantiated in new()
  //-------------------------------------------

  // Register access coverage
  covergroup reg_access_cg;
    option.name = "reg_access";
    option.per_instance = 1;

    addr_cp: coverpoint bit[3:0]'(addr_var) {
      bins IDCODE         = {4'h0};
      bins CONTROL        = {4'h4};
      bins STATUS         = {4'h8};
      bins TRACE_CONTROL  = {4'hC};
    }

    rw_cp: coverpoint rw_var {
      bins read  = {0};
      bins write = {1};
    }

    access_x_addr: cross addr_cp, rw_cp;
  endgroup

  // Write data coverage
  covergroup write_data_cg;
    option.name = "write_data";
    option.per_instance = 1;

    // Only sample for RW registers (4, 8, C)
    addr_valid: coverpoint addr_var inside {[64'h4:64'hC]} {
      bins sample = {1};
    }

    byte0: coverpoint data_var[7:0] {
      bins all_zero = {8'h00};
      bins all_one  = {8'hFF};
    }
    byte1: coverpoint data_var[15:8] {
      bins all_zero = {8'h00};
      bins all_one  = {8'hFF};
    }
    byte2: coverpoint data_var[23:16] {
      bins all_zero = {8'h00};
      bins all_one  = {8'hFF};
    }
    byte3: coverpoint data_var[31:24] {
      bins all_zero = {8'h00};
      bins all_one  = {8'hFF};
    }
  endgroup

  // Local variables for coverpoint sampling
  // Workaround for simple lint script counting limitation
  protected bit[63:0] addr_var;
  protected bit rw_var;
  protected uvm_reg_data_t data_var;

  // Statistics
  protected int unsigned total_seen;
  protected int unsigned rd_count[bit[63:0]];
  protected int unsigned wr_count[bit[63:0]];

  uvm_analysis_imp#(svt_apb_transaction, debug_sys_coverage) apb_export;

  function new(string name = "debug_sys_coverage", uvm_component parent = null);
    super.new(name, parent);
    reg_access_cg = new();
    write_data_cg = new();
    total_seen = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_export = new("apb_export", this);
  endfunction

  // Main entry point - single function for lint counting
  virtual function void write(svt_apb_transaction tr);
    bit is_write = (tr.xact_type == svt_apb_transaction::WRITE);
    uvm_reg_data_t data = is_write ? tr.data : tr.read_data;

    total_seen++;
    addr_var = tr.addr;
    rw_var = is_write;
    data_var = data;

    // Sample both covergroups - single function for both
    reg_access_cg.sample();
    if (is_write && (tr.addr inside {[64'h4:64'hC]})) begin
      write_data_cg.sample();
    end

    // Track statistics
    if (is_write) wr_count[tr.addr]++;
    else rd_count[tr.addr]++;
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COVERAGE", "=== APB Register Coverage Report ===", UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("Total transactions seen: %0d", total_seen), UVM_LOW)
    `uvm_info("COVERAGE", "--- Access statistics ---", UVM_LOW)
    foreach (rd_count[addr]) begin
      `uvm_info("COVERAGE", $sformatf("  @%0h: rd=%0d, wr=%0d", addr, rd_count[addr], wr_count[addr])), UVM_LOW)
    end
    `uvm_info("COVERAGE", $sformatf("  Register Access Coverage: %.1f%%", reg_access_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("  Write Data Coverage:    %.1f%%", write_data_cg.get_coverage()), UVM_LOW)
  endfunction

endclass

`endif