// ==========================================
// Custom ATB Configuration
// ==========================================
`ifndef CUST_ATB_CFG_SV
`define CUST_ATB_CFG_SV

class cust_atb_cfg extends svt_atb_system_configuration;

  `uvm_object_utils(cust_atb_cfg)

  function new(string name = "cust_atb_cfg", virtual svt_atb_if vif = null);
    super.new(name, vif);

    this.num_masters = 1;
    this.num_slaves = 1;
    this.create_sub_cfgs(1, 1);

    // Arm CoreSight ATB standard configuration
    this.master_cfg[0].is_active = 1'b1;
    this.slave_cfg[0].is_active = 1'b1;
    this.master_cfg[0].atb_port_kind = svt_atb_port_configuration::ATB_MASTER;
    this.master_cfg[0].atb_interface_type = svt_atb_port_configuration::ATB1_1;
    this.master_cfg[0].data_width = 32;          // CoreSight standard: 32-bit
    this.slave_cfg[0].data_width = 32;
    this.master_cfg[0].id_width = 7;             // 7-bit ATID
    this.slave_cfg[0].id_width = 7;
    this.slave_cfg[0].default_atready = 1'b1;    // Always ready by default

    // Flush and sync (common for trace systems)
    this.master_cfg[0].flush_request_enable = 1'b0;
    this.slave_cfg[0].flush_request_enable = 1'b0;
    this.master_cfg[0].synchronization_enable = 1'b0;
    this.slave_cfg[0].synchronization_enable = 1'b0;

  endfunction

endclass

`endif