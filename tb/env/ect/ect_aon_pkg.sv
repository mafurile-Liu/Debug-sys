`ifndef ECT_AON_PKG_SV
`define ECT_AON_PKG_SV

// ------------------------------------------------------------------
// AON ECT verification agent package.
//
// This package provides the first reusable framework for injecting and
// observing AON ECT events/channels.  Register programming sequences are
// intentionally not part of this package yet; they may later live in C
// test cases or a separate APB sequence.
// ------------------------------------------------------------------

package ect_aon_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"

  typedef enum int unsigned {
    ECT_AON_CTI_EVT_IN   = 0,
    ECT_AON_CTI_EVT_OUT  = 1,
    ECT_M52_CTI_EVT_IN   = 2,
    ECT_M52_CTI_EVT_OUT  = 3,
    ECT_CTM_AON_CH_IN    = 4,
    ECT_CTM_AON_CH_OUT   = 5,
    ECT_CTM_M52_CH_IN    = 6,
    ECT_CTM_M52_CH_OUT   = 7,
    ECT_CTM_TOP_CH_IN    = 8,
    ECT_CTM_TOP_CH_OUT   = 9
  } ect_aon_loc_e;

  typedef enum int unsigned {
    ECT_OP_PULSE = 0,
    ECT_OP_LEVEL = 1,
    ECT_OP_HANDSHAKE = 2
  } ect_aon_op_e;

  // Widths come from the current ECT_Event_Mapping/sys_aon interface view.
  function automatic int unsigned ect_aon_loc_width(ect_aon_loc_e loc);
    case (loc)
      ECT_AON_CTI_EVT_IN  : return 10;
      ECT_AON_CTI_EVT_OUT : return 15;
      ECT_M52_CTI_EVT_IN  : return 6;
      ECT_M52_CTI_EVT_OUT : return 8;
      ECT_CTM_AON_CH_IN   : return 16;
      ECT_CTM_AON_CH_OUT  : return 16;
      ECT_CTM_M52_CH_IN   : return 4;
      ECT_CTM_M52_CH_OUT  : return 4;
      ECT_CTM_TOP_CH_IN   : return 16;
      ECT_CTM_TOP_CH_OUT  : return 16;
      default             : return 0;
    endcase
  endfunction

  function automatic bit ect_aon_ack_exists(
    ect_aon_loc_e loc,
    int unsigned   index
  );
    case (loc)
      ECT_AON_CTI_EVT_IN:
        return (index == 6) || (index == 7);
      ECT_AON_CTI_EVT_OUT:
        return (index == 7) || (index == 8) || (index == 14);
      default: return 1'b0;
    endcase
  endfunction

  function automatic logic ect_aon_sample_ack(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index
  );
    case ({loc, index})
      {ECT_AON_CTI_EVT_IN,  6} : return vif.hifi_cti_out_ack;
      {ECT_AON_CTI_EVT_IN,  7} : return vif.hifi_break_out_ack;
      {ECT_AON_CTI_EVT_OUT, 7} : return vif.hifi_cti_in_ack;
      {ECT_AON_CTI_EVT_OUT, 8} : return vif.hifi_break_in_ack;
      {ECT_AON_CTI_EVT_OUT, 14}: return vif.tbu_pmusnapshot_ack;
      default: return 1'b0;
    endcase
  endfunction

  function automatic logic ect_aon_sample_bit(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index
  );
    case (loc)
      ECT_AON_CTI_EVT_IN  : return vif.cti_aon_evt_in[index];
      ECT_AON_CTI_EVT_OUT : return vif.cti_aon_evt_out[index];
      ECT_M52_CTI_EVT_IN  : return vif.cti_m52_evt_in[index];
      ECT_M52_CTI_EVT_OUT : return vif.cti_m52_evt_out[index];
      ECT_CTM_AON_CH_IN   : return vif.ctm_aon_ch_in[index];
      ECT_CTM_AON_CH_OUT  : return vif.ctm_aon_ch_out[index];
      ECT_CTM_M52_CH_IN   : return vif.ctm_m52_ch_in[index];
      ECT_CTM_M52_CH_OUT  : return vif.ctm_m52_ch_out[index];
      ECT_CTM_TOP_CH_IN   : return vif.ctm_top_ch_in[index];
      ECT_CTM_TOP_CH_OUT  : return vif.ctm_top_ch_out[index];
      default             : return 1'bx;
    endcase
  endfunction

  function automatic void ect_aon_drive_bit(
    virtual ect_aon_if vif,
    ect_aon_loc_e      loc,
    int unsigned       index,
    logic              value
  );
    case (loc)
      ECT_AON_CTI_EVT_IN  : vif.cti_aon_evt_in[index]  = value;
      ECT_M52_CTI_EVT_IN  : vif.cti_m52_evt_in[index]  = value;
      ECT_CTM_AON_CH_IN   : vif.ctm_aon_ch_in[index]   = value;
      ECT_CTM_M52_CH_IN   : vif.ctm_m52_ch_in[index]   = value;
      ECT_CTM_TOP_CH_IN   : vif.ctm_top_ch_in[index]   = value;
      default: `uvm_warning("ECT_AON_DRV",
        $sformatf("Location %s is not an injection path", loc.name()))
    endcase
  endfunction

  class ect_aon_cfg extends uvm_object;
    virtual ect_aon_if vif;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    int unsigned default_pulse_cycles    = 1;
    int unsigned default_timeout_cycles  = 100;
    bit          enable_transition_check = 1'b1;

    `uvm_object_utils_begin(ect_aon_cfg)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
      `uvm_field_int(default_pulse_cycles,    UVM_DEFAULT)
      `uvm_field_int(default_timeout_cycles,  UVM_DEFAULT)
      `uvm_field_int(enable_transition_check, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "ect_aon_cfg");
      super.new(name);
    endfunction
  endclass

  class ect_aon_item extends uvm_sequence_item;
    rand ect_aon_op_e   op;
    rand ect_aon_loc_e  loc;
    rand int unsigned   index;
    rand logic          value;
    rand int unsigned   pulse_cycles;

    int unsigned timeout_cycles;
    time         timestamp;

    constraint c_valid_index_c {
      index < ect_aon_loc_width(loc);
    }

    constraint c_pulse_cycles_c {
      pulse_cycles inside {[1:16]};
    }

    `uvm_object_utils_begin(ect_aon_item)
      `uvm_field_enum(ect_aon_op_e,  op,   UVM_DEFAULT)
      `uvm_field_enum(ect_aon_loc_e, loc,  UVM_DEFAULT)
      `uvm_field_int(index,        UVM_DEFAULT)
      `uvm_field_int(value,        UVM_DEFAULT)
      `uvm_field_int(pulse_cycles, UVM_DEFAULT)
      `uvm_field_int(timeout_cycles, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "ect_aon_item");
      super.new(name);
      timestamp = $time;
    endfunction

    virtual function string convert2string();
      return $sformatf(
        "op=%s loc=%s index=%0d value=%0b pulse=%0d timeout=%0d @%0t",
        op.name(), loc.name(), index, value,
        pulse_cycles, timeout_cycles, timestamp
      );
    endfunction
  endclass

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
           loc_id <= ECT_CTM_TOP_CH_OUT;
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

  class ect_aon_driver extends uvm_driver#(ect_aon_item);
    virtual ect_aon_if vif;
    ect_aon_cfg        cfg;

    `uvm_component_utils(ect_aon_driver)

    function new(string name = "ect_aon_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(ect_aon_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ect_aon_cfg::type_id::create("cfg");
        `uvm_info("ECT_AON_DRV", "No cfg in config_db, created default", UVM_MEDIUM)
      end

      if (cfg.vif == null) begin
        if (!uvm_config_db#(virtual ect_aon_if)::get(this, "", "vif", cfg.vif)) begin
          `uvm_fatal("ECT_AON_DRV", "AON ECT virtual interface not found")
        end
      end

      vif = cfg.vif;
    endfunction

    virtual task run_phase(uvm_phase phase);
      ect_aon_item item;

      forever begin
        seq_item_port.get_next_item(item);
        drive_item(item);
        seq_item_port.item_done();
      end
    endtask

    local task drive_item(ect_aon_item item);
      if (item == null) return;

      case (item.op)
        ECT_OP_PULSE: begin
          int unsigned cycles = (item.pulse_cycles != 0) ?
                                item.pulse_cycles : cfg.default_pulse_cycles;

          ect_aon_drive_bit(vif, item.loc, item.index, 1'b1);
          repeat (cycles) @(posedge vif.clk);
          ect_aon_drive_bit(vif, item.loc, item.index, 1'b0);
          @(posedge vif.clk);
        end

        ECT_OP_LEVEL: begin
          ect_aon_drive_bit(vif, item.loc, item.index, item.value);
          @(posedge vif.clk);
        end

        ECT_OP_HANDSHAKE: begin
          bit          ack_seen;
          int unsigned timeout;

          ack_seen = 1'b0;
          timeout  = (item.timeout_cycles != 0) ?
                     item.timeout_cycles : cfg.default_timeout_cycles;

          if (!ect_aon_ack_exists(item.loc, item.index)) begin
            `uvm_error("ECT_AON_DRV", $sformatf(
              "No handshake ack mapped: loc=%s index=%0d",
              item.loc.name(), item.index))
          end else begin
            ect_aon_drive_bit(vif, item.loc, item.index, 1'b1);

            for (int unsigned cycle = 0;
                 cycle < timeout && !ack_seen;
                 cycle++) begin
              @(posedge vif.clk);
              ack_seen = ect_aon_sample_ack(vif, item.loc, item.index);
            end

            ect_aon_drive_bit(vif, item.loc, item.index, 1'b0);

            if (!ack_seen) begin
              `uvm_error("ECT_AON_DRV", $sformatf(
                "Handshake ack timeout: loc=%s index=%0d timeout=%0d",
                item.loc.name(), item.index, timeout))
            end
          end

          @(posedge vif.clk);
        end

        default: begin
          `uvm_error("ECT_AON_DRV", $sformatf("Unsupported op: %s", item.op.name()))
        end
      endcase

      item.timestamp = $time;
    endtask
  endclass

  class ect_aon_expectation extends uvm_object;
    ect_aon_loc_e loc;
    int unsigned  index;
    logic         expected_value;
    int unsigned  timeout_cycles;

    `uvm_object_utils(ect_aon_expectation)

    function new(string name = "ect_aon_expectation");
      super.new(name);
    endfunction

    function string key();
      return $sformatf("%s_%0d", loc.name(), index);
    endfunction
  endclass

  typedef uvm_sequencer#(ect_aon_item) ect_aon_sequencer;

  // Minimal directed pulse sequence.  A test selects one ECT location/index
  // and the agent drives it as a one-cycle-or-longer pulse.
  class ect_aon_pulse_sequence extends uvm_sequence#(ect_aon_item);
    rand ect_aon_loc_e loc          = ECT_AON_CTI_EVT_IN;
    rand int unsigned  index        = 0;
    rand logic         value        = 1'b1;
    rand int unsigned  pulse_cycles = 1;

    constraint c_valid_index_c {
      index < ect_aon_loc_width(loc);
    }

    constraint c_pulse_cycles_c {
      pulse_cycles inside {[1:16]};
    }

    `uvm_object_utils(ect_aon_pulse_sequence)

    function new(string name = "ect_aon_pulse_sequence");
      super.new(name);
    endfunction

    virtual task body();
      ect_aon_item item;

      item = ect_aon_item::type_id::create("item");
      start_item(item);

      item.op          = ECT_OP_PULSE;
      item.loc         = loc;
      item.index       = index;
      item.value       = value;
      item.pulse_cycles = pulse_cycles;

      finish_item(item);
    endtask
  endclass

  // Directed handshake sequence.  The selected event request is held high
  // until the mapped acknowledgement is observed or the timeout expires.
  class ect_aon_handshake_sequence extends uvm_sequence#(ect_aon_item);
    rand ect_aon_loc_e loc            = ECT_AON_CTI_EVT_IN;
    rand int unsigned  index          = 6;
    rand int unsigned  timeout_cycles = 100;

    constraint c_valid_index_c {
      index < ect_aon_loc_width(loc);
      ect_aon_ack_exists(loc, index);
    }

    `uvm_object_utils(ect_aon_handshake_sequence)

    function new(string name = "ect_aon_handshake_sequence");
      super.new(name);
    endfunction

    virtual task body();
      ect_aon_item item;

      item = ect_aon_item::type_id::create("item");
      start_item(item);

      item.op             = ECT_OP_HANDSHAKE;
      item.loc            = loc;
      item.index          = index;
      item.value          = 1'b1;
      item.timeout_cycles = timeout_cycles;

      finish_item(item);
    endtask
  endclass

  class ect_aon_agent extends uvm_agent;
    ect_aon_cfg        cfg;
    ect_aon_monitor    monitor;
    ect_aon_driver     driver;
    ect_aon_sequencer  sequencer;

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
    endfunction
  endclass

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

endpackage

`endif


