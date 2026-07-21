`ifndef DEBUG_SYS_SCOREBOARD_SV
`define DEBUG_SYS_SCOREBOARD_SV

// Scoreboard now compares predictor-generated EXPECTED transactions against
// out-monitor ACTUAL transactions, per exit port. This replaces the old
// per-fabric in_q/out_q equality compare so cross-port address routing can be
// checked: the predictor decides which exit port a transaction should appear on.
class debug_sys_scoreboard extends uvm_scoreboard;
  // Expected (from predictor)
  uvm_analysis_imp_exp_apb   #(svt_apb_transaction,      debug_sys_scoreboard) apb_exp;
  uvm_analysis_imp_exp_axi   #(svt_axi_transaction,      debug_sys_scoreboard) axi_exp;
  uvm_analysis_imp_exp_atb   #(svt_atb_transaction,      debug_sys_scoreboard) atb_exp;
  uvm_analysis_imp_exp_debug #(debug_port_transaction_t, debug_sys_scoreboard) debug_exp;
  // Actual (from out-monitors)
  uvm_analysis_imp_act_apb   #(svt_apb_transaction,      debug_sys_scoreboard) apb_actual;
  uvm_analysis_imp_act_axi   #(svt_axi_transaction,      debug_sys_scoreboard) axi_actual;
  uvm_analysis_imp_act_atb   #(svt_atb_transaction,      debug_sys_scoreboard) atb_actual;
  uvm_analysis_imp_act_debug #(debug_port_transaction_t, debug_sys_scoreboard) debug_actual;

  svt_apb_transaction      apb_exp_q[$],  apb_act_q[$];
  svt_axi_transaction      axi_exp_q[$],  axi_act_q[$];
  svt_atb_transaction      atb_exp_q[$],  atb_act_q[$];
  debug_port_transaction_t debug_exp_q[$], debug_act_q[$];

  int unsigned apb_matches,   apb_mismatches;
  int unsigned axi_matches,   axi_mismatches;
  int unsigned atb_matches,   atb_mismatches;
  int unsigned debug_matches, debug_mismatches;

  `uvm_component_utils(debug_sys_scoreboard)

  function new(string name = "debug_sys_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    apb_exp   = new("apb_exp",   this); apb_actual  = new("apb_actual",   this);
    axi_exp   = new("axi_exp",   this); axi_actual  = new("axi_actual",   this);
    atb_exp   = new("atb_exp",   this); atb_actual  = new("atb_actual",   this);
    debug_exp = new("debug_exp", this); debug_actual= new("debug_actual", this);
  endfunction

  // ---- expected writers (from predictor) ----
  function void write_exp_apb  (svt_apb_transaction item);
    svt_apb_transaction c; if ($cast(c, item.clone())) apb_exp_q.push_back(c); compare_apb();   endfunction
  function void write_exp_axi  (svt_axi_transaction item);
    svt_axi_transaction c; if ($cast(c, item.clone())) axi_exp_q.push_back(c); compare_axi();   endfunction
  function void write_exp_atb  (svt_atb_transaction item);
    svt_atb_transaction c; if ($cast(c, item.clone())) atb_exp_q.push_back(c); compare_atb();   endfunction
  function void write_exp_debug(debug_port_transaction_t item);
    debug_port_transaction_t c; if ($cast(c, item.clone())) debug_exp_q.push_back(c); compare_debug(); endfunction

  // ---- actual writers (from out-monitors) ----
  function void write_act_apb  (svt_apb_transaction item);
    svt_apb_transaction c; if ($cast(c, item.clone())) apb_act_q.push_back(c); compare_apb();   endfunction
  function void write_act_axi  (svt_axi_transaction item);
    svt_axi_transaction c; if ($cast(c, item.clone())) axi_act_q.push_back(c); compare_axi();   endfunction
  function void write_act_atb  (svt_atb_transaction item);
    svt_atb_transaction c; if ($cast(c, item.clone())) atb_act_q.push_back(c); compare_atb();   endfunction
  function void write_act_debug(debug_port_transaction_t item);
    debug_port_transaction_t c; if ($cast(c, item.clone())) debug_act_q.push_back(c); compare_debug(); endfunction

  // ---- per-exit-port expected-vs-actual compare (in-order) ----
  // NOTE: in-order FIFO works when the DUT preserves order per exit port.
  // For reordering paths (e.g. AXI with remapped IDs), replace with tag/ID
  // keyed association - see TODO in compare_axi.
  function void compare_apb();
    svt_apb_transaction e, a;
    while (apb_exp_q.size() && apb_act_q.size()) begin
      e = apb_exp_q.pop_front(); a = apb_act_q.pop_front();
      if (!e.compare(a)) begin `uvm_error("APB_MISMATCH", "APB actual differs from predicted"); apb_mismatches++; end
      else apb_matches++;
    end
  endfunction
  function void compare_axi();
    // TODO: switch to AXI-ID-keyed matching once DUT reorders. In-order for now.
    svt_axi_transaction e, a;
    while (axi_exp_q.size() && axi_act_q.size()) begin
      e = axi_exp_q.pop_front(); a = axi_act_q.pop_front();
      if (!e.compare(a)) begin `uvm_error("AXI_MISMATCH", "AXI actual differs from predicted"); axi_mismatches++; end
      else axi_matches++;
    end
  endfunction
  function void compare_atb();
    svt_atb_transaction e, a;
    while (atb_exp_q.size() && atb_act_q.size()) begin
      e = atb_exp_q.pop_front(); a = atb_act_q.pop_front();
      if (!e.compare(a)) begin `uvm_error("ATB_MISMATCH", "ATB actual differs from predicted"); atb_mismatches++; end
      else atb_matches++;
    end
  endfunction
  function void compare_debug();
    debug_port_transaction_t e, a;
    while (debug_exp_q.size() && debug_act_q.size()) begin
      e = debug_exp_q.pop_front(); a = debug_act_q.pop_front();
      if (!e.compare(a)) begin `uvm_error("DEBUG_MISMATCH", "DEBUG actual differs from predicted"); debug_mismatches++; end
      else debug_matches++;
    end
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (apb_exp_q.size()   || apb_act_q.size())   `uvm_error("APB_PENDING",   "Unmatched APB transactions remain")
    if (axi_exp_q.size()   || axi_act_q.size())   `uvm_error("AXI_PENDING",   "Unmatched AXI transactions remain")
    if (atb_exp_q.size()   || atb_act_q.size())   `uvm_error("ATB_PENDING",   "Unmatched ATB transactions remain")
    if (debug_exp_q.size() || debug_act_q.size()) `uvm_error("DEBUG_PENDING", "Unmatched DEBUG transactions remain")
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", $sformatf(
      "matched DEBUG=%0d APB=%0d AXI=%0d ATB=%0d | mismatched DEBUG=%0d APB=%0d AXI=%0d ATB=%0d",
      debug_matches, apb_matches, axi_matches, atb_matches,
      debug_mismatches, apb_mismatches, axi_mismatches, atb_mismatches), UVM_LOW)
  endfunction
endclass

`endif