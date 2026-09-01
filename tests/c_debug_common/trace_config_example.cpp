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
     *   -> replicator(both) -> ETF HW FIFO + ETR -> CATU(pass-through) */
    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS, /* mode */
                   0x07U,                  /* funnel slave ports 0,1,2 */
                   AON_SRAM_BASE_ADDR,     /* ETR buffer addr */
                   0x00010000U,            /* buffer size (unused: RSZ RO) */
                   CATU_SLADDR_DEFAULT);   /* CATU scatter list (unused in bypass) */

    /* dbg_ss trace tree: STM -> funnel (port 0) -> ETR -> CATU(translate) */
    dbg_ss_trace_init(TRACE_MODE_ETF_CATU_TRANSLATE,  /* mode */
                      0x01U,                 /* funnel slave port 0 */
                      AON_SRAM_BASE_ADDR,    /* ETR buffer addr */
                      0x00010000U,           /* buffer size */
                      CATU_SLADDR_DEFAULT);  /* CATU scatter list @ AON SRAM + 0x10000 */

    /* Interrupt / error-path tests:
     *   TRACE_MODE_ETR_SWF1_FULL_INT - ETR SWF1 full IRQ (BUFWM=max, fires after 1 word)
     *   TRACE_MODE_CATU_ADDRERR  - CATU ADDRERR IRQ (INADDR deliberately wrong)
     *   aon_trace_init(TRACE_MODE_ETR_SWF1_FULL_INT, 0x07U, 0, 0, 0);
     *   dbg_ss_trace_init(TRACE_MODE_CATU_ADDRERR, 0x01U, AON_SRAM_BASE_ADDR, 0x10000U, 0);
     */

    c_uvm_info("trace config done");
    C_PASS();
CPU_TEST_END
