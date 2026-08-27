`ifndef DEBUG_SYS_PREDICTOR_SV
`define DEBUG_SYS_PREDICTOR_SV

// Predicts the expected output transaction on the correct exit port for each
// input transaction, based on debug_sys_addr_map. Cross-protocol transforms
// are stubbed (TODO) until the DUT bridge spec is available; same-protocol
// identity transforms are implemented so standalone loopback still works.
class debug_sys_predictor extends uvm_component;
  debug_sys_addr_map map;
  debug_sys_cfg      cfg;

  // Inputs from in-monitors
  uvm_analysis_imp_pred_apb_in   #(svt_apb_transaction,        debug_sys_predictor) apb_in;
  uvm_analysis_imp_pred_axi_in   #(svt_axi_transaction,        debug_sys_predictor) axi_in;
  uvm_analysis_imp_pred_atb_in   #(svt_atb_transaction,        debug_sys_predictor) atb_in;
  uvm_analysis_imp_pred_debug_in #(debug_port_transaction_t,   debug_sys_predictor) debug_in;

  // Expected outputs to scoreboard
  uvm_analysis_port #(svt_apb_transaction)      apb_exp;
  uvm_analysis_port #(svt_axi_transaction)      axi_exp;
  uvm_analysis_port #(svt_atb_transaction)      atb_exp;
  uvm_analysis_port #(debug_port_transaction_t) debug_exp;

  `uvm_component_utils(debug_sys_predictor)

  function new(string name = "debug_sys_predictor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(debug_sys_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = debug_sys_cfg::type_id::create("cfg");
      `uvm_info("PRED", "No cfg in config_db, created default", UVM_MEDIUM)
    end
    map = cfg.addr_map;
    if (map == null) begin
      map = debug_sys_addr_map::type_id::create("map");
      map.configure_standalone();
    end

    apb_in   = new("apb_in",   this);
    axi_in   = new("axi_in",   this);
    atb_in   = new("atb_in",   this);
    debug_in = new("debug_in", this);
    apb_exp  = new("apb_exp",  this);
    axi_exp  = new("axi_exp",  this);
    atb_exp  = new("atb_exp",  this);
    debug_exp= new("debug_exp",this);
  endfunction

  // ---- address accessors (override get_atb_addr / get_debug_addr for DUT) ----
  virtual function bit [63:0] get_apb_addr  (svt_apb_transaction tr);      return tr.addr; endfunction
  virtual function bit [63:0] get_axi_addr  (svt_axi_transaction tr);      return tr.addr; endfunction
  virtual function bit [63:0] get_atb_addr  (svt_atb_transaction tr);      return 64'h0;   endfunction
  virtual function bit [63:0] get_debug_addr(debug_port_transaction_t tr); return 64'h0;   endfunction

  // ---- input write hooks (called by analysis imps) ----
  function void write_pred_apb_in  (svt_apb_transaction tr);      predict_apb  (tr); endfunction
  function void write_pred_axi_in  (svt_axi_transaction tr);      predict_axi  (tr); endfunction
  function void write_pred_atb_in  (svt_atb_transaction tr);      predict_atb  (tr); endfunction
  function void write_pred_debug_in(debug_port_transaction_t tr); predict_debug(tr); endfunction

  // ---- routing dispatch ----
  function void predict_apb(svt_apb_transaction tr);
    debug_sys_port_e xp; bit [63:0] ea; bit term;
    if (map == null) return;
    if (!map.lookup(DEBUG_SYS_PORT_APB, get_apb_addr(tr), xp, ea, term)) begin
      `uvm_warning("PRED_UNMAPPED", $sformatf("APB addr %0h unmapped", get_apb_addr(tr)))
      return;
    end
    if (term) return;
    case (xp)
      DEBUG_SYS_PORT_APB: emit_apb_from_apb(tr, ea);
      DEBUG_SYS_PORT_AXI: emit_axi_from_apb(tr, ea);
      default: `uvm_warning("PRED_ROUT", $sformatf("APB->%0s not modeled", xp.name()))
    endcase
  endfunction

  function void predict_axi(svt_axi_transaction tr);
    debug_sys_port_e xp; bit [63:0] ea; bit term;
    if (map == null) return;
    if (!map.lookup(DEBUG_SYS_PORT_AXI, get_axi_addr(tr), xp, ea, term)) begin
      `uvm_warning("PRED_UNMAPPED", $sformatf("AXI addr %0h unmapped", get_axi_addr(tr)))
      return;
    end
    if (term) return;
    case (xp)
      DEBUG_SYS_PORT_AXI: emit_axi_from_axi(tr, ea);
      DEBUG_SYS_PORT_APB: emit_apb_from_axi(tr, ea);
      default: `uvm_warning("PRED_ROUT", $sformatf("AXI->%0s not modeled", xp.name()))
    endcase
  endfunction

  function void predict_atb(svt_atb_transaction tr);
    debug_sys_port_e xp; bit [63:0] ea; bit term;
    if (map == null) return;
    if (!map.lookup(DEBUG_SYS_PORT_ATB, get_atb_addr(tr), xp, ea, term)) begin
      `uvm_warning("PRED_UNMAPPED", $sformatf("ATB unmapped"))
      return;
    end
    if (term) return;
    case (xp)
      DEBUG_SYS_PORT_ATB: emit_atb_from_atb(tr);
      default: `uvm_warning("PRED_ROUT", $sformatf("ATB->%0s not modeled", xp.name()))
    endcase
  endfunction

  function void predict_debug(debug_port_transaction_t tr);
    debug_sys_port_e xp; bit [63:0] ea; bit term;
    if (map == null) return;
    if (!map.lookup(DEBUG_SYS_PORT_DEBUG, get_debug_addr(tr), xp, ea, term)) begin
      `uvm_warning("PRED_UNMAPPED", $sformatf("DEBUG unmapped"))
      return;
    end
    if (term) return;
    case (xp)
      DEBUG_SYS_PORT_DEBUG: emit_debug_from_debug(tr);
      DEBUG_SYS_PORT_APB:   emit_apb_from_debug(tr, ea);
      DEBUG_SYS_PORT_AXI:   emit_axi_from_debug(tr, ea);
      default: `uvm_warning("PRED_ROUT", $sformatf("DEBUG->%0s not modeled", xp.name()))
    endcase
  endfunction

  // ---- identity transforms (implemented) ----
  function void emit_apb_from_apb(svt_apb_transaction in_tr, bit [63:0] ea);
    svt_apb_transaction e;
    if (!$cast(e, in_tr.clone())) begin
      `uvm_error("PRED_CLONE", "APB clone failed"); return;
    end
    e.addr = ea;
    apb_exp.write(e);
  endfunction

  function void emit_axi_from_axi(svt_axi_transaction in_tr, bit [63:0] ea);
    svt_axi_transaction e;
    if (!$cast(e, in_tr.clone())) begin
      `uvm_error("PRED_CLONE", "AXI clone failed"); return;
    end
    e.addr = ea;
    axi_exp.write(e);
  endfunction

  function void emit_atb_from_atb(svt_atb_transaction in_tr);
    svt_atb_transaction e;
    if (!$cast(e, in_tr.clone())) begin
      `uvm_error("PRED_CLONE", "ATB clone failed"); return;
    end
    atb_exp.write(e);
  endfunction

  function void emit_debug_from_debug(debug_port_transaction_t in_tr);
    debug_port_transaction_t e;
    if (!$cast(e, in_tr.clone())) begin
      `uvm_error("PRED_CLONE", "DEBUG clone failed"); return;
    end
    debug_exp.write(e);
  endfunction

  // ---- cross-protocol transforms (STUBS; fill when DUT bridge spec is known) ----
  // Example routes the user named: SWD/JTAG -> APB, SWD/JTAG -> AXI, APB -> AXI.
  function void emit_axi_from_apb  (svt_apb_transaction in_tr, bit [63:0] ea);
    `uvm_info("PRED_TODO", "xform APB->AXI not implemented; fill per DUT bridge", UVM_MEDIUM)
    // TODO: build svt_axi_transaction from in_tr (direction/addr=ea/size/data), write to axi_exp.
  endfunction
  function void emit_apb_from_axi  (svt_axi_transaction in_tr, bit [63:0] ea);
    `uvm_info("PRED_TODO", "xform AXI->APB not implemented; fill per DUT bridge", UVM_MEDIUM)
  endfunction
  function void emit_apb_from_debug(debug_port_transaction_t in_tr, bit [63:0] ea);
    `uvm_info("PRED_TODO", "xform DEBUG->APB not implemented; fill per DUT bridge", UVM_MEDIUM)
  endfunction
  function void emit_axi_from_debug(debug_port_transaction_t in_tr, bit [63:0] ea);
    `uvm_info("PRED_TODO", "xform DEBUG->AXI not implemented; fill per DUT bridge", UVM_MEDIUM)
  endfunction
endclass

`endif
