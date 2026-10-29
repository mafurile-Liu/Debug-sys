`ifndef ECTAONAGENT_SVH
`define ECTAONAGENT_SVH

  class ect_aon_agent extends uvm_agent;
    ect_aon_cfg        cfg;
    ect_aon_monitor    monitor;
    ect_aon_driver     driver;
    ect_aon_sequencer  sequencer;
    ect_aon_coverage   coverage;

    `uvm_component_utils(ect_aon_agent)

    function new(string name = "ect_aon_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(ect_aon_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ect_aon_cfg::type_id::create("cfg");
        `uvm_info("ECT_AON_AGENT", "No cfg in config_db, created default", UVM_MEDIUM)
      end

      if (cfg.vif == null) begin
        if (!uvm_config_db#(virtual ect_aon_if)::get(this, "", "vif", cfg.vif)) begin
          `uvm_fatal("ECT_AON_AGENT", "AON ECT virtual interface not found")
        end
      end

      monitor = ect_aon_monitor::type_id::create("monitor", this);
      uvm_config_db#(ect_aon_cfg)::set(this, "monitor", "cfg", cfg);

      if (cfg.enable_coverage) begin
        coverage = ect_aon_coverage::type_id::create("coverage", this);
      end

      if (cfg.is_active == UVM_ACTIVE) begin
        driver    = ect_aon_driver::type_id::create("driver", this);
        sequencer = ect_aon_sequencer::type_id::create("sequencer", this);
        uvm_config_db#(ect_aon_cfg)::set(this, "driver", "cfg", cfg);
      end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      if (cfg.is_active == UVM_ACTIVE && driver != null && sequencer != null) begin
        driver.seq_item_port.connect(sequencer.seq_item_export);
      end

      if (coverage != null) begin
        monitor.ap.connect(coverage.analysis_export);

        if (driver != null) begin
          driver.ap.connect(coverage.analysis_export);
        end
      end
    endfunction
  endclass

`endif
