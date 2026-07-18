`ifndef DEBUG_SYS_ANALYSIS_DECLS_SVH
`define DEBUG_SYS_ANALYSIS_DECLS_SVH

// Analysis port declarations shared by predictor and scoreboard.
// Declared once here (package scope) so both classes see the same write_* names.

// Predictor inputs (driven by in-monitors)
`uvm_analysis_imp_decl(_pred_apb_in)
`uvm_analysis_imp_decl(_pred_axi_in)
`uvm_analysis_imp_decl(_pred_atb_in)
`uvm_analysis_imp_decl(_pred_debug_in)

// Scoreboard: expected (from predictor) vs actual (from out-monitors)
`uvm_analysis_imp_decl(_exp_apb)
`uvm_analysis_imp_decl(_act_apb)
`uvm_analysis_imp_decl(_exp_axi)
`uvm_analysis_imp_decl(_act_axi)
`uvm_analysis_imp_decl(_exp_atb)
`uvm_analysis_imp_decl(_act_atb)
`uvm_analysis_imp_decl(_exp_debug)
`uvm_analysis_imp_decl(_act_debug)

// Shared transaction typedef (was previously inside debug_sys_scoreboard.sv)
`ifdef DEBUG_PORT_JTAG
typedef svt_jtag_transaction debug_port_transaction_t;
`elsif DEBUG_PORT_SWD
typedef svt_swd_transaction debug_port_transaction_t;
`endif

`endif
