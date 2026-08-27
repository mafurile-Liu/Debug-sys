`ifndef DEBUG_PORT_SMOKE_TEST_SV
`define DEBUG_PORT_SMOKE_TEST_SV

class debug_port_smoke_test extends debug_port_base_test;
  `uvm_component_utils(debug_port_smoke_test)

  function new(string name = "debug_port_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge env.vseqr.reset_vif.clk);

    // Check APB env is built
    if (env.apb_env == null) begin
      `uvm_error("NO_APB", "APB environment was not built")
    end

    // Check port env is built (always present with JTAG+SWD agents)
    if (env.port_env == null) begin
      `uvm_error("NO_PORT", "Debug port environment was not built")
    end

    // Check ATB env is built
    if (cfg.enable_atb && env.atb_env == null) begin
      `uvm_error("NO_ATB", "ATB environment was not built")
    end

    // Print active protocol (from plusarg)
    `uvm_info("SMOKE", $sformatf("Active protocol: %s",
      cfg.port_protocol.name()), UVM_LOW)

    `uvm_info("SMOKE",
      "JTAG+SWD port / APB / ATB environment is alive (protocol selected via +debug_port_proto)",
      UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass

`endif
