`ifndef DEBUG_SYS_SCOREBOARD_SV
`define DEBUG_SYS_SCOREBOARD_SV

`uvm_analysis_imp_decl(_apb_in)
`uvm_analysis_imp_decl(_apb_out)
`uvm_analysis_imp_decl(_axi_in)
`uvm_analysis_imp_decl(_axi_out)
`uvm_analysis_imp_decl(_atb_in)
`uvm_analysis_imp_decl(_atb_out)
`uvm_analysis_imp_decl(_debug_in)
`uvm_analysis_imp_decl(_debug_out)

`ifdef DEBUG_PORT_JTAG
typedef svt_jtag_transaction debug_port_transaction_t;
`elsif DEBUG_PORT_SWD
typedef svt_swd_transaction debug_port_transaction_t;
`endif

class debug_sys_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp_apb_in #(svt_apb_transaction, debug_sys_scoreboard) apb_in;
  uvm_analysis_imp_apb_out #(svt_apb_transaction, debug_sys_scoreboard) apb_out;
  uvm_analysis_imp_axi_in #(svt_axi_transaction, debug_sys_scoreboard) axi_in;
  uvm_analysis_imp_axi_out #(svt_axi_transaction, debug_sys_scoreboard) axi_out;
  uvm_analysis_imp_atb_in #(svt_atb_transaction, debug_sys_scoreboard) atb_in;
  uvm_analysis_imp_atb_out #(svt_atb_transaction, debug_sys_scoreboard) atb_out;
  uvm_analysis_imp_debug_in #(debug_port_transaction_t, debug_sys_scoreboard) debug_in;
  uvm_analysis_imp_debug_out #(debug_port_transaction_t, debug_sys_scoreboard) debug_out;

  svt_apb_transaction apb_in_q[$];
  svt_apb_transaction apb_out_q[$];
  svt_axi_transaction axi_in_q[$];
  svt_axi_transaction axi_out_q[$];
  svt_atb_transaction atb_in_q[$];
  svt_atb_transaction atb_out_q[$];
  debug_port_transaction_t debug_in_q[$];
  debug_port_transaction_t debug_out_q[$];

  int unsigned apb_matches;
  int unsigned axi_matches;
  int unsigned atb_matches;
  int unsigned debug_matches;

  `uvm_component_utils(debug_sys_scoreboard)

  function new(string name = "debug_sys_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    apb_in = new("apb_in", this);
    apb_out = new("apb_out", this);
    axi_in = new("axi_in", this);
    axi_out = new("axi_out", this);
    atb_in = new("atb_in", this);
    atb_out = new("atb_out", this);
    debug_in = new("debug_in", this);
    debug_out = new("debug_out", this);
  endfunction

  function void write_debug_in(debug_port_transaction_t item);
    debug_port_transaction_t copy;
    if ($cast(copy, item.clone())) debug_in_q.push_back(copy);
    compare_debug();
  endfunction

  function void write_debug_out(debug_port_transaction_t item);
    debug_port_transaction_t copy;
    if ($cast(copy, item.clone())) debug_out_q.push_back(copy);
    compare_debug();
  endfunction

  function void write_apb_in(svt_apb_transaction item);
    svt_apb_transaction copy;
    if ($cast(copy, item.clone())) apb_in_q.push_back(copy);
    compare_apb();
  endfunction

  function void write_apb_out(svt_apb_transaction item);
    svt_apb_transaction copy;
    if ($cast(copy, item.clone())) apb_out_q.push_back(copy);
    compare_apb();
  endfunction

  function void write_axi_in(svt_axi_transaction item);
    svt_axi_transaction copy;
    if ($cast(copy, item.clone())) axi_in_q.push_back(copy);
    compare_axi();
  endfunction

  function void write_axi_out(svt_axi_transaction item);
    svt_axi_transaction copy;
    if ($cast(copy, item.clone())) axi_out_q.push_back(copy);
    compare_axi();
  endfunction

  function void write_atb_in(svt_atb_transaction item);
    svt_atb_transaction copy;
    if ($cast(copy, item.clone())) atb_in_q.push_back(copy);
    compare_atb();
  endfunction

  function void write_atb_out(svt_atb_transaction item);
    svt_atb_transaction copy;
    if ($cast(copy, item.clone())) atb_out_q.push_back(copy);
    compare_atb();
  endfunction

  function void compare_apb();
    svt_apb_transaction lhs;
    svt_apb_transaction rhs;
    while (apb_in_q.size() && apb_out_q.size()) begin
      lhs = apb_in_q.pop_front();
      rhs = apb_out_q.pop_front();
      if (!lhs.compare(rhs)) begin
        `uvm_error("APB_MISMATCH", "APB master/slave observations differ")
      end
      else begin
        apb_matches++;
      end
    end
  endfunction

  function void compare_debug();
    debug_port_transaction_t lhs;
    debug_port_transaction_t rhs;
    while (debug_in_q.size() && debug_out_q.size()) begin
      lhs = debug_in_q.pop_front();
      rhs = debug_out_q.pop_front();
      if (!lhs.compare(rhs)) begin
        `uvm_error("DEBUG_MISMATCH", "JTAG/SWD endpoint observations differ")
      end
      else begin
        debug_matches++;
      end
    end
  endfunction

  function void compare_axi();
    svt_axi_transaction lhs;
    svt_axi_transaction rhs;
    while (axi_in_q.size() && axi_out_q.size()) begin
      lhs = axi_in_q.pop_front();
      rhs = axi_out_q.pop_front();
      if (!lhs.compare(rhs)) begin
        `uvm_error("AXI_MISMATCH", "AXI master/slave observations differ")
      end
      else begin
        axi_matches++;
      end
    end
  endfunction

  function void compare_atb();
    svt_atb_transaction lhs;
    svt_atb_transaction rhs;
    while (atb_in_q.size() && atb_out_q.size()) begin
      lhs = atb_in_q.pop_front();
      rhs = atb_out_q.pop_front();
      if (!lhs.compare(rhs)) begin
        `uvm_error("ATB_MISMATCH", "ATB master/slave observations differ")
      end
      else begin
        atb_matches++;
      end
    end
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (apb_in_q.size() || apb_out_q.size()) begin
      `uvm_error("APB_PENDING", "Unmatched APB transactions remain")
    end
    if (axi_in_q.size() || axi_out_q.size()) begin
      `uvm_error("AXI_PENDING", "Unmatched AXI transactions remain")
    end
    if (atb_in_q.size() || atb_out_q.size()) begin
      `uvm_error("ATB_PENDING", "Unmatched ATB transactions remain")
    end
    if (debug_in_q.size() || debug_out_q.size()) begin
      `uvm_error("DEBUG_PENDING", "Unmatched JTAG/SWD transactions remain")
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", $sformatf(
      "matched DEBUG=%0d APB=%0d AXI=%0d ATB=%0d",
      debug_matches, apb_matches, axi_matches, atb_matches), UVM_LOW)
  endfunction
endclass

`endif
