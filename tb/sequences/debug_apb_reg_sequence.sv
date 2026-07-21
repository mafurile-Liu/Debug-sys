`ifndef DEBUG_APB_REG_SEQUENCE_SV
`define DEBUG_APB_REG_SEQUENCE_SV

// APB Register Access Sequence - Protocol Layer
// This sequence provides primitive register access methods
// It is intended to be extended by Feature/Scenario sequences
class debug_apb_reg_sequence extends uvm_reg_sequence;

  `uvm_object_utils(debug_apb_reg_sequence)
  `uvm_declare_p_sequencer(debug_sys_virtual_sequencer)

  function new(string name = "debug_apb_reg_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("APB_REG", "APB register access sequence started", UVM_LOW)
  endtask

  // Write to a register via RAL
  virtual task write_reg(uvm_reg rg, uvm_reg_data_t data);
    uvm_status_e status;
    rg.write(status, data, UVM_FRONTDOOR, p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK) begin
      `uvm_error("REG_WRITE", $sformatf("Register %s write failed", rg.get_full_name()))
    end
  endtask

  // Read from a register via RAL
  virtual task read_reg(uvm_reg rg, output uvm_reg_data_t data);
    uvm_status_e status;
    rg.read(status, data, UVM_FRONTDOOR, p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK) begin
      `uvm_error("REG_READ", $sformatf("Register %s read failed", rg.get_full_name()))
    end
  endtask

  // Write then read back and verify
  virtual task write_and_verify_reg(uvm_reg rg, uvm_reg_data_t data);
    uvm_reg_data_t readback;
    write_reg(rg, data);
    read_reg(rg, readback);
    if (readback !== data) begin
      `uvm_error("REG_VERIFY", $sformatf(
        "Register %s mismatch: wrote=0x%08h, read=0x%08h",
        rg.get_full_name(), data, readback))
    end
  endtask

endclass

`endif