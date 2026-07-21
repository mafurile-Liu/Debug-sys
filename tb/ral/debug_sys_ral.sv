`ifndef DEBUG_SYS_RAL_SV
`define DEBUG_SYS_RAL_SV

class debug_reg32 extends uvm_reg;
  rand uvm_reg_field value;
  string access = "RW";
  uvm_reg_data_t reset_value = '0;

  `uvm_object_utils(debug_reg32)

  function new(string name = "debug_reg32");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, access, 0, reset_value, 1, 0, 1);
  endfunction
endclass

class debug_sys_reg_block extends uvm_reg_block;
  rand debug_reg32 idcode;
  rand debug_reg32 control;
  rand debug_reg32 status;
  rand debug_reg32 trace_control;

  `uvm_object_utils(debug_sys_reg_block)

  function new(string name = "debug_sys_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    default_map = create_map("apb_map", 'h0, 4, UVM_LITTLE_ENDIAN, 0);

    idcode = debug_reg32::type_id::create("idcode");
    idcode.access = "RO";
    idcode.reset_value = 32'hD06D_0001;
    idcode.configure(this, null, "");
    idcode.build();
    default_map.add_reg(idcode, 'h000, "RO");

    control = debug_reg32::type_id::create("control");
    control.access = "RW";
    control.configure(this, null, "");
    control.build();
    default_map.add_reg(control, 'h004, "RW");

    status = debug_reg32::type_id::create("status");
    status.access = "RO";
    status.configure(this, null, "");
    status.build();
    default_map.add_reg(status, 'h008, "RO");

    trace_control = debug_reg32::type_id::create("trace_control");
    trace_control.access = "RW";
    trace_control.configure(this, null, "");
    trace_control.build();
    default_map.add_reg(trace_control, 'h00c, "RW");
  endfunction
endclass

`endif

