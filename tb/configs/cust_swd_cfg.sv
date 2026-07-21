// ==========================================
// Custom SWD Configuration
// ==========================================
`ifndef CUST_SWD_CFG_SV
`define CUST_SWD_CFG_SV

class cust_swd_master_cfg extends svt_swd_agent_configuration;

  `uvm_object_utils(cust_swd_master_cfg)

  function new(string name = "cust_swd_master_cfg");
    super.new(name);

    this.is_active = 1'b1;
    this.device_type = svt_swd_types::SWD_MASTER;
    this.WCR_turnaround_period = 1;       // Standard 1-cycle turnaround
    this.clock_period_ps = 10000;          // 100 MHz clock
    this.enable_get_response = 1'b1;
    this.protocol_checks_enable = 1'b1;
    this.coverage_enable = 1'b1;

  endfunction

endclass

class cust_swd_slave_cfg extends svt_swd_agent_configuration;

  `uvm_object_utils(cust_swd_slave_cfg)

  function new(string name = "cust_swd_slave_cfg");
    super.new(name);

    this.is_active = 1'b1;
    this.device_type = svt_swd_types::SWD_SLAVE;
    this.WCR_turnaround_period = 1;
    this.enable_get_response = 1'b1;

  endfunction

endclass

`endif