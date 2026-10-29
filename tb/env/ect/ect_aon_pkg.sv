`ifndef ECT_AON_PKG_SV
`define ECT_AON_PKG_SV

// ------------------------------------------------------------------
// AON ECT verification agent package.
//
// The implementation is split by component to keep the package readable.
// `ect_aon_if` must be compiled before this package.
// ------------------------------------------------------------------

package ect_aon_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"

  // Types, location maps, and shared helper functions.
  `include "ect_aon_types.svh"

  // Configuration and sequence items.
  `include "ect_aon_cfg.svh"
  `include "ect_aon_item.svh"

  // Signal-level components.
  `include "ect_aon_monitor.svh"
  `include "ect_aon_driver.svh"

  // Check objects and stimulus.
  `include "ect_aon_expectation.svh"
  `include "ect_aon_sequences.svh"

  // Components that consume or aggregate other components.
  `include "ect_aon_coverage.svh"
  `include "ect_aon_agent.svh"
  `include "ect_aon_scoreboard.svh"

endpackage

`endif
