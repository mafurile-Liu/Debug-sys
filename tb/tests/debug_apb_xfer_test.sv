`ifndef DEBUG_APB_XFER_TEST_SV
`define DEBUG_APB_XFER_TEST_SV

/**
 * APB 收发验证测试
 *
 * 在 main_phase 中启动 debug_apb_xfer_sequence，
 * 通过现有 apb_master_env.master.sequencer 驱动。
 * scoreboard 和 slave memory sequence 由 base_test 配置。
 */
class debug_apb_xfer_test extends debug_port_base_test;
  `uvm_component_utils(debug_apb_xfer_test)

  function new(string name = "debug_apb_xfer_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_apb_xfer();
    phase.drop_objection(this);
  endtask
endclass

`endif