`ifndef DEBUG_PORT_BASE_TEST_SV
`define DEBUG_PORT_BASE_TEST_SV

class debug_port_base_test extends uvm_test;
  debug_sys_cfg cfg;
  debug_sys_env env;

  `uvm_component_utils(debug_port_base_test)

  function new(string name = "debug_port_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = debug_sys_cfg::type_id::create("cfg");
    uvm_config_db#(debug_sys_cfg)::set(this, "env", "cfg", cfg);

    uvm_config_db#(uvm_object_wrapper)::set(
      this,
      "env.apb_slave_env.slave*.sequencer.run_phase",
      "default_sequence",
      svt_apb_slave_memory_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)::set(
      this,
      "env.atb_env.slave*.sequencer.run_phase",
      "default_sequence",
      svt_atb_slave_response_sequence::type_id::get());

    env = debug_sys_env::type_id::create("env", this);
  endfunction

  virtual task reset_phase(uvm_phase phase);
    debug_reset_sequence reset_seq;
    phase.raise_objection(this);
    reset_seq = debug_reset_sequence::type_id::create("reset_seq");
    reset_seq.start(env.vseqr);
    if (env.regmodel != null) env.regmodel.reset();
    phase.drop_objection(this);
  endtask

  virtual task run_entry_smoke();
    debug_entry_sequence entry_seq;
    entry_seq = debug_entry_sequence::type_id::create("entry_seq");
    entry_seq.start(env.vseqr.port_sequencer);
  endtask

  virtual task run_reg_smoke();
    uvm_status_e status;
    uvm_reg_data_t readback;

    env.regmodel.control.write(status, 32'hA5A5_5A5A, UVM_FRONTDOOR,
                               env.regmodel.default_map, this);
    if (status != UVM_IS_OK) begin
      `uvm_error("RAL_WRITE", "APB RAL control write failed")
    end

    env.regmodel.control.read(status, readback, UVM_FRONTDOOR,
                              env.regmodel.default_map, this);
    if (status != UVM_IS_OK) begin
      `uvm_error("RAL_READ", "APB RAL control read failed")
    end
    if (readback != 32'hA5A5_5A5A) begin
      `uvm_error("RAL_DATA", $sformatf("expected A5A55A5A, got %08h", readback))
    end
  endtask

  virtual task run_trace_smoke();
    svt_atb_random_system_sequence trace_seq;
    uvm_config_db#(int unsigned)::set(
      null, "*.svt_atb_master_random_sequence", "sequence_length", 8);
    trace_seq = svt_atb_random_system_sequence::type_id::create("trace_seq");
    trace_seq.start(env.vseqr.atb_sequencer);
  endtask
endclass

`endif
