`ifndef ECTAONITEM_SVH
`define ECTAONITEM_SVH

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

`endif
