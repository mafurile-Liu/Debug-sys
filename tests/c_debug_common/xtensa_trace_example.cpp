#include "drv_debug.h"

CPU_TEST_START
    OPEN_DEBUG_CRG();

    /* Route HiFi trace into the AON trace tree on Funnel_5 M3. */
    aon_trace_init(TRACE_MODE_ETF_ATB_ONLY,
                   1u << HIFI_TRACE_FUNNEL_SLAVE_PORT,
                   AON_SRAM_BASE_ADDR,
                   CATU_SLADDR_DEFAULT);

    /* Enable HiFi TRAX output on ATB. */
    hifi_trace_atb_start(0x01u, 0x01u, true);

    uint32_t stat = hifi_trace_atb_status();
    if ((stat & TRAXSTAT_TRACT) == 0u) {
        c_uvm_error("hifi_trace_atb_case: trace is not active");
    } else {
        c_uvm_info("hifi_trace_atb_case: TRAXSTAT=0x%x", stat);
    }

    hifi_trace_atb_stop();
    C_PASS();
CPU_TEST_END
