`ifndef ECTAONSCOREBOARD_SVH
`define ECTAONSCOREBOARD_SVH

  class ect_aon_scoreboard extends uvm_scoreboard;
    virtual ect_aon_if vif;
    ect_aon_cfg        cfg;

    uvm_analysis_imp#(ect_aon_item, ect_aon_scoreboard) analysis_export;

    local ect_aon_expectation expectations[$];
    local int unsigned observed_count[string];
    local logic       observed_value[string];
    local bit         observed_valid[string];

    `uvm_component_utils(ect_aon_scoreboard)

    function new(string name = "ect_aon_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(ect_aon_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ect_aon_cfg::type_id::create("cfg");
        `uvm_info("ECT_AON_SB", "No cfg in config_db, created default", UVM_MEDIUM)
      end

      if (cfg.vif == null) begin
        if (!uvm_config_db#(virtual ect_aon_if)::get(this, "", "vif", cfg.vif)) begin
          `uvm_fatal("ECT_AON_SB", "AON ECT virtual interface not found")
        end
      end

      vif = cfg.vif;
    endfunction

    function void expect_event(
      ect_aon_loc_e loc,
      int unsigned  index,
      logic         expected_value,
      int unsigned  timeout_cycles = 0
    );
      ect_aon_expectation exp;

      if (index >= ect_aon_loc_width(loc)) begin
        `uvm_error("ECT_AON_SB", $sformatf(
          "Invalid expected index: loc=%s index=%0d width=%0d",
          loc.name(), index, ect_aon_loc_width(loc)))
        return;
      end

      exp = ect_aon_expectation::type_id::create("expectation");
      exp.loc            = loc;
      exp.index          = index;
      exp.expected_value = expected_value;
      exp.timeout_cycles = (timeout_cycles != 0) ?
                           timeout_cycles : cfg.default_timeout_cycles;

      expectations.push_back(exp);
      `uvm_info("ECT_AON_SB", $sformatf(
        "Added expectation: %s", exp.convert2string()), UVM_MEDIUM)
    endfunction

    local function string item_key(ect_aon_item item);
      return $sformatf("%s_%0d", item.loc.name(), item.index);
    endfunction

    local function void process_event(ect_aon_item item);
      string key = item_key(item);

      observed_count[key]++;
      observed_value[key] = item.value;
      observed_valid[key] = 1'b1;

      for (int unsigned i = 0; i < expectations.size(); i++) begin
        if (expectations[i].loc   == item.loc &&
            expectations[i].index == item.index) begin
          if (expectations[i].expected_value === item.value) begin
            `uvm_info("ECT_AON_SB", $sformatf(
              "Matched expectation: %s", item.convert2string()), UVM_MEDIUM)
            expectations.delete(i);
            return;
          end
        end
      end
    endfunction

    virtual function void write(ect_aon_item item);
      if (item != null) begin
        process_event(item);
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);

        for (int unsigned i = expectations.size(); i > 0; i--) begin
          int unsigned idx = i - 1;

          if (expectations[idx].timeout_cycles == 0) begin
            `uvm_error("ECT_AON_SB", $sformatf(
              "ECT expectation timeout: loc=%s index=%0d expected=%0b",
              expectations[idx].loc.name(),
              expectations[idx].index,
              expectations[idx].expected_value))
            expectations.delete(idx);
          end else begin
            expectations[idx].timeout_cycles--;
          end
        end
      end
    endtask

    function int unsigned get_observed_count(ect_aon_loc_e loc, int unsigned index);
      string key = $sformatf("%s_%0d", loc.name(), index);
      return observed_count.exists(key) ? observed_count[key] : 0;
    endfunction

    function logic get_observed_value(ect_aon_loc_e loc, int unsigned index);
      string key = $sformatf("%s_%0d", loc.name(), index);
      return observed_valid.exists(key) ? observed_value[key] : 1'bx;
    endfunction
  endclass

`endif
