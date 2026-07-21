`ifndef DEBUG_SEQ_PKG_SV
`define DEBUG_SEQ_PKG_SV

// ==========================================
// SEQUENCE PACKAGE - All sequences in one place
// ==========================================
// Layered Sequence Architecture:
//
//   Layer 3: Scenario Sequences (debug_apb_scenario_sequence)
//      ? ?? Feature ?
//   Layer 2: Feature Sequences  (debug_apb_reg_test_sequence)
//      ? ?? Protocol ??
//   Layer 1: Protocol Sequences (debug_apb_reg_sequence)
//      ? ?? RAL read/write
//   Layer 0: Register Access Layer (RAL)
//
// This package contains ALL sequence definitions.
// Compiled BEFORE env_pkg and test_pkg.
// ==========================================

package debug_seq_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"
  `include "svt_jtag_defines.svi"
  `include "svt_jtypes.svi"
  `include "svt_swd_defines.svi"
  `include "svt_apb_defines.svi"
  `include "svt_axi_defines.svi"
  `include "svt_atb_defines.svi"

  // Reset and entry sequences
  `include "debug_reset_sequence.sv"
  `include "debug_entry_sequence.sv"

  // Layer 1: Protocol sequences - RAL primitives
  `include "debug_apb_reg_sequence.sv"

  // Layer 2: Feature sequences - complete test features
  `include "debug_apb_reg_test_sequence.sv"

  // Layer 3: Scenario sequences - combination of features
  `include "debug_apb_scenario_sequence.sv"

  // DEPRECATED - Legacy direct transaction sequence
  `include "debug_apb_xfer_sequence.sv"

endpackage

`endif