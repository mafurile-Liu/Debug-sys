/*
 * c_config_m52_trace_CORES_m52/main.cpp
 *
 * Minimal self-hosted M52 ITM/ETM trace case.
 *
 * This program runs on the M52 core and accesses the core's PPB registers
 * directly. It uses the shared AON trace helper for readability and does not
 * use <stdio.h> or the AHB-AP TAR/DRW debug path.
 */

#include "drv_common.h"
#include "drv_debug.h"

/* M52 PPB registers (M52 TRM). */
#define M52_ITM_STIM(port)  (0xE0000000U + ((port) * 4U))
#define M52_ITM_TER         0xE0000E00U
#define M52_ITM_TCR         0xE0000E80U
#define M52_ITM_TCR_VAL     ((1U << 16) | (1U << 3) | 1U)
#define M52_ETM_BASE        0xE0041000U
#define M52_ETM_LAR         (M52_ETM_BASE + 0xFB0U)
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define ETM_LAR_KEY         0xC5ACCE55U

COP_TEST_START
    OPEN_DEBUG_CRG();

    /*
     * Route M52 ITM/ETM through the shared AON trace helper:
     * funnel(port1/port2) -> ETF -> replicator -> ETR -> AON SRAM.
     */
    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   0x06U,
                   AON_SRAM_BASE_ADDR,
                   0x00010000U,
                   CATU_SLADDR_DEFAULT);

    /* Enable M52 debug trace logic. */
    W32(M52_DEMCR, M52_DEMCR_TRCENA);

    /* Enable all ITM stimulus ports and the ITM ATB interface. */
    W32(M52_ITM_TER, 0xFFFFFFFFU);
    W32(M52_ITM_TCR, M52_ITM_TCR_VAL);

    /* Unlock ETM, set trace ID, then enable the programmer. */
    W32(M52_ETM_LAR, ETM_LAR_KEY);
    W32(M52_ETM_TRCTRACEIDR, 0x00000002U);
    W32(M52_ETM_TRCPRGCTLR, 0x00000001U);

    /*
     * ITM only emits ATB data when software writes a stimulus port. Keep this
     * loop tiny; it also provides enough data to exercise downstream flushing.
     */
    for (unsigned int i = 0U; i < 16U; ++i) {
        W32(M52_ITM_STIM(0), 0xC0DE0000U + i);
    }

    c_uvm_info("%s", "m52 direct itm/etm trace enabled");
    C_PASS();
COP_TEST_END
