`ifndef ECTAONEXPECTATION_SVH
`define ECTAONEXPECTATION_SVH

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

`endif
