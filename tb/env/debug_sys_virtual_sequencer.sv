`ifndef DEBUG_SYS_VIRTUAL_SEQUENCER_SV
`define DEBUG_SYS_VIRTUAL_SEQUENCER_SV

class debug_sys_virtual_sequencer extends
  uvm_sequencer#(uvm_sequence_item, uvm_sequence_item);

  typedef virtual debug_reset_if.seq_mp reset_vif_t;
  reset_vif_t reset_vif;

`ifdef DEBUG_PORT_JTAG
  svt_jtag_transaction_sequencer port_sequencer;
`elsif DEBUG_PORT_SWD
  svt_swd_transaction_sequencer port_sequencer;
`endif

  svt_apb_master_sequencer apb_sequencer;
  svt_atb_system_sequencer atb_sequencer;
  debug_sys_reg_block regmodel;

  `uvm_component_utils(debug_sys_virtual_sequencer)

  function new(string name = "debug_sys_virtual_sequencer",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(reset_vif_t)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NO_RESET_VIF", "debug_reset_if.seq_mp was not configured")
    end
  endfunction
endclass

`endif

