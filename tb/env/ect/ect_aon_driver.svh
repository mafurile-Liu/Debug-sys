`ifndef ECTAONDRIVER_SVH
`define ECTAONDRIVER_SVH

  class ect_aon_driver extends uvm_driver#(ect_aon_item);
    virtual ect_aon_if vif;
    ect_aon_cfg        cfg;

    uvm_analysis_port#(ect_aon_item) ap;

    `uvm_component_utils(ect_aon_driver)

    function new(string name = "ect_aon_driver", uvm_component parent = null);
      super.new(name, parent);
      ap = new("ap", this);
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
      ap.write(item);
    endtask
  endclass

`endif
