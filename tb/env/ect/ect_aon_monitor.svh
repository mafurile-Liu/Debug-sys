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
      forever begin
        @(posedge vif.clk);
        sample_all_locs();
      end
    endtask

    local function void sample_all_locs();
      for (int unsigned loc_id = ECT_AON_CTI_EVT_IN;
           loc_id <= ECT_AON_ACK_TBU;
           loc_id++) begin
        sample_loc(ect_aon_loc_e'(loc_id));
      end
    endfunction

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
