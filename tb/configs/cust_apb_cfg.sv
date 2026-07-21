// ==========================================
// Custom APB Configuration
// ==========================================
// This file overrides default SVT APB VIP configuration.
// Place project-specific settings here.
// Compiled BEFORE SVT VIP packages.
// ==========================================

`ifndef CUST_APB_CFG_SV
`define CUST_APB_CFG_SV

class cust_apb_cfg extends svt_apb_system_configuration;

  `uvm_object_utils(cust_apb_cfg)

  function new(string name = "cust_apb_cfg");
    super.new(name);

    // ==========================================
    // Bus Width Configuration (most common setup)
    // ==========================================
    this.ADDR_WIDTH = 16;   // 16-bit address (covers 64KB register space)
    this.DATA_WIDTH = 32;   // 32-bit data (standard for Arm peripherals)

    // ==========================================
    // Feature Enable/Disable
    // ==========================================
    this.protocol_checks_enable = 1'b1;    // Enable protocol checker
    thiscoverage_enable = 1'b1;              // Enable coverage collection
    this.num_masters = 1;                     // Single master
    this.num_slaves = 1;                      // Single slave

    // ==========================================
    // UVM Register Layer Support
    // ==========================================
    this.uvm_reg_enable = 1'b1;              // Enable RAL adapter

  endfunction

endclass

`endif