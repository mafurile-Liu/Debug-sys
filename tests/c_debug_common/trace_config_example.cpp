/*
 * trace_config_example.cpp
 *
 * Example usage of aon_trace_init() / dbg_ss_trace_init().
 * Follows the same style as tests/c_debug_direct_tests/main.cpp.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"
#include "aon_crg.hpp"
#include "coresight_trace_regs.h"

/* Functions implemented in trace_config.c */
extern "C" {
void aon_trace_init(trace_mode_t mode,
                    uint32_t     funnel_slave_port_mask,
                    uint32_t     etr_buf_addr,
                    uint32_t     etr_buf_size);

void dbg_ss_trace_init(trace_mode_t mode,
                       uint32_t     funnel_slave_port_mask,
                       uint32_t     etr_buf_addr,
                       uint32_t     etr_buf_size,
                       uint32_t     tpiu_port_size);
}

CPU_TEST_START
{
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* AON trace tree: M52/HIFI trace -> funnel (ports 0,1,2) -> ETR -> CATU */
    aon_trace_init(TRACE_MODE_ETR_CATU,   /* mode */
                   0x07U,                 /* funnel slave ports 0,1,2 enabled */
                   0x10000000U,           /* ETR buffer (CATU-translated) */
                   0x00010000U);          /* buffer size 64KB */

    /* dbg_ss trace tree: STM -> funnel (port 0) -> ETF (on-chip FIFO) */
    dbg_ss_trace_init(TRACE_MODE_ETF_ONCHIP, /* mode */
                      0x01U,                  /* funnel slave port 0 enabled */
                      0U,                     /* ETR buffer not used */
                      0U,                     /* ETR size not used */
                      0U);                    /* TPIU port size not used */

    c_uvm_info("trace config done");
    C_PASS();
}
CPU_TEST_END