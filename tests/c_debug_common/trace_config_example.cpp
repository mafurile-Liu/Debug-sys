/*
 * trace_config_example.cpp
 *
 * Example usage of aon_trace_init() / dbg_ss_trace_init().
 * drv_debug.h pulls in drv_common.h (W32/R32, c_uvm_info, C_PASS,
 * CPU_TEST_START/END, OPEN_DEBUG_CRG) and coresight_trace_regs.h.
 */

#include "drv_debug.h"

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* AON trace tree: M52/HIFI trace -> funnel (ports 0,1,2)
     *   -> replicator(both) -> ETF + ETR -> CATU(pass-through) */
    aon_trace_init(TRACE_MODE_CATU_BYPASS, /* mode */
                   0x07U,                  /* funnel slave ports 0,1,2 */
                   0x10000000U,            /* ETR buffer addr (DRAM) */
                   0x00010000U,            /* buffer size (unused: RSZ RO) */
                   CATU_SLADDR_DEFAULT);   /* CATU scatter list (unused in bypass) */

    /* dbg_ss trace tree: STM -> funnel (port 0) -> ETR -> CATU(translate) */
    dbg_ss_trace_init(TRACE_MODE_ETR_CATU,  /* mode */
                      0x01U,                 /* funnel slave port 0 */
                      0x10000000U,           /* ETR buffer addr */
                      0x00010000U,           /* buffer size */
                      CATU_SLADDR_DEFAULT);  /* CATU scatter list @ 0x27400000 */

    /* Interrupt / error-path tests:
     *   TRACE_MODE_FULL_INT      - ETF full IRQ (BUFWM=max, fires after 1 word)
     *   TRACE_MODE_CATU_ADDRERR  - CATU ADDRERR IRQ (INADDR deliberately wrong)
     *   aon_trace_init(TRACE_MODE_FULL_INT,     0x07U, 0, 0, 0);
     *   dbg_ss_trace_init(TRACE_MODE_CATU_ADDRERR, 0x01U, 0x10000000U, 0x10000U, 0);
     */

    c_uvm_info("trace config done");
    C_PASS();
CPU_TEST_END