`ifndef ECTAONSEQUENCES_SVH
`define ECTAONSEQUENCES_SVH

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

  // Run all currently mapped request/ack paths.  The driver waits for each
  // mapped acknowledgement, so this sequence also enables request->ack pair
  // coverage.
  class ect_aon_all_handshake_pairs_sequence extends uvm_sequence#(ect_aon_item);
    rand int unsigned timeout_cycles = 100;

    protected ect_aon_loc_e req_loc[5] = '{
      ECT_AON_CTI_EVT_IN,
      ECT_AON_CTI_EVT_IN,
      ECT_AON_CTI_EVT_OUT,
      ECT_AON_CTI_EVT_OUT,
      ECT_AON_CTI_EVT_OUT
    };

    protected int unsigned req_idx[5] = '{6, 7, 7, 8, 14};

    `uvm_object_utils(ect_aon_all_handshake_pairs_sequence)

    function new(string name = "ect_aon_all_handshake_pairs_sequence");
      super.new(name);
    endfunction

    virtual task body();
      for (int unsigned path = 0; path < 5; path++) begin
        ect_aon_item item;

        item = ect_aon_item::type_id::create($sformatf("item_%0d", path));
        start_item(item);

        item.op             = ECT_OP_HANDSHAKE;
        item.loc            = req_loc[path];
        item.index          = req_idx[path];
        item.value          = 1'b1;
        item.timeout_cycles = timeout_cycles;

        finish_item(item);
      end
    endtask
  endclass

`endif
