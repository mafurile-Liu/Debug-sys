// ==========================================
// Custom AXI Monitor Configuration
// ==========================================
`ifndef CUST_AXI_CFG_SV
`define CUST_AXI_CFG_SV

class cust_axi_monitor_cfg extends svt_axi_system_configuration;

  `uvm_object_utils(cust_axi_monitor_cfg)

  function new(string name = "cust_axi_monitor_cfg");
    super.new(name);

    this.num_masters = 1;
    this.num_slaves = 1;
    this.create_sub_cfgs(1, 1);

    // Common configuration for Arm AXI
    this.master_cfg[0].is_active = 1'b0;       // Passive monitor only
    this.slave_cfg[0].is_active = 1'b0;
    this.master_cfg[0].data_width = 32;         // 32-bit data bus
    this.slave_cfg[0].data_width = 32;
    this.master_cfg[0].id_width = 4;            // 4-bit ID
    this.slave_cfg[0].id_width = 4;
    this.master_cfg[0].addr_width = 32;         // 32-bit address
    this.slave_cfg[0].addr_width = 32;

    this.master_cfg[0].protocol_checks_enable = 1'b1;
    this.slave_cfg[0].protocol_checks_enable = 1'b1;

    // Address decode: map all 4GB space
    this.set_addr_range(0, 64'h0, 64'hFFFFFFFF);

  endfunction

endclass

`endif