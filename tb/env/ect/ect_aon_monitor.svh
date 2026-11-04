`ifndef ECTAONMONITOR_SVH
`define ECTAONMONITOR_SVH

  class ect_aon_monitor extends uvm_monitor;
    virtual ect_aon_if vif;
    ect_aon_cfg        cfg;

    uvm_analysis_port#(ect_aon_item) ap;

    local bit m_valid[string];
    local logic m_value[string];

    `uvm_component_utils(ect_aon_monitor)

    function new(string name = "ect_aon_monitor", uvm_component parent = null);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(ect_aon_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ect_aon_cfg::type_id::create("cfg");
        `uvm_info("ECT_AON_MON", "No cfg in config_db, created default", UVM_MEDIUM)
      end

      if (cfg.vif == null) begin
        if (!uvm_config_db#(virtual ect_aon_if)::get(this, "", "vif", cfg.vif)) begin
          `uvm_fatal("ECT_AON_MON", "AON ECT virtual interface not found")
        end
      end

      vif = cfg.vif;
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
        monitor_source_domain();
        monitor_trace_domain();
      join
    endtask

    // IP/CTI source events are sampled in the APB/source clock domain.
    local task monitor_source_domain();
      forever begin
        @(posedge vif.clk);
        sample_loc(ECT_AON_CTI_EVT_IN);
        sample_loc(ECT_M52_CTI_EVT_IN);
        sample_loc(ECT_AON_ACK_HIFI_CTI_OUT);
        sample_loc(ECT_AON_ACK_HIFI_BREAK_OUT);
        sample_loc(ECT_AON_ACK_HIFI_CTI_IN);
        sample_loc(ECT_AON_ACK_HIFI_BREAK_IN);
        sample_loc(ECT_AON_ACK_TBU);
      end
    endtask

    // CTI outputs and CTM channel outputs are sampled in the AON trace clock
    // domain.  This avoids missing single-cycle pulses when the TB interface
    // clock is the slower APB clock.
    local task monitor_trace_domain();
      forever begin
        @(posedge vif.clk_trace_aon);
        sample_loc(ECT_AON_CTI_EVT_OUT);
        sample_loc(ECT_CTM_AON_CH_IN);
        sample_loc(ECT_CTM_AON_CH_OUT);
        sample_loc(ECT_CTM_M52_CH_IN);
        sample_loc(ECT_CTM_M52_CH_OUT);
        sample_loc(ECT_CTM_M52_CH_IN_DRV);
        sample_loc(ECT_CTM_TOP_CH_IN);
        sample_loc(ECT_CTM_TOP_CH_OUT);
      end
    endtask

    local function void sample_loc(ect_aon_loc_e loc);
      for (int unsigned index = 0; index < ect_aon_loc_width(loc); index++) begin
        string key;
        logic  value;

        key   = $sformatf("%s_%0d", loc.name(), index);
        value = ect_aon_sample_bit(vif, loc, index);

        if (!m_valid.exists(key) || m_value[key] !== value) begin
          if (cfg.enable_transition_check && m_valid.exists(key)) begin
            ect_aon_item item = ect_aon_item::type_id::create("event");
            item.op        = ECT_OP_LEVEL;
            item.loc       = loc;
            item.index     = index;
            item.value     = value;
            item.timestamp = $time;
            ap.write(item);
          end

          m_valid[key] = 1'b1;
          m_value[key] = value;
        end
      end
    endfunction
  endclass

`endif
