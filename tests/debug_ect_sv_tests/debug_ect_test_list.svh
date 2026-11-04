`ifndef DEBUG_ECT_TEST_LIST_SVH
`define DEBUG_ECT_TEST_LIST_SVH

// Add this file once from the Linux test package:
//   `include "debug_ect_sv_tests/debug_ect_test_list.svh"

//`include "debug_ect_sv_tests/debug_ect_smoke_test.sv"
`include "debug_ect_sv_tests/debug_ect_route_etf_full_to_trigin_test.sv"
`include "debug_ect_sv_tests/debug_ect_route_etf_full_multi_channel_test.sv"
`include "debug_ect_sv_tests/debug_ect_evt_in0_to9_direct_map_test.sv"
`include "debug_ect_sv_tests/debug_ect_top_chin_to_evtout_pulse_test.sv"
`include "debug_ect_sv_tests/debug_ect_top_chin_to_evtout_handshake_test.sv"
`include "debug_ect_sv_tests/debug_ect_evtin6_7_hs_to_ch14_15_test.sv"

`endif
