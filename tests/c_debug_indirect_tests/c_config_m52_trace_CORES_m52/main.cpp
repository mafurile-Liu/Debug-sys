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
#define M52_ITM_LAR         0xE0000FB0U
#define M52_ITM_TER         0xE0000E00U
#define M52_ITM_TCR         0xE0000E80U
#define M52_ITM_TCR_VAL     ((1U << 16) | (1U << 3) | (1U << 2) | 1U)
#define M52_ETM_BASE        0xE0041000U
#define M52_ETM_LAR         (M52_ETM_BASE + 0xFB0U)
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCSTATR    (M52_ETM_BASE + 0x00CU)
#define M52_ETM_TRCCONFIGR  (M52_ETM_BASE + 0x010U)
#define M52_ETM_TRCEVENTCTL0R (M52_ETM_BASE + 0x020U)
#define M52_ETM_TRCEVENTCTL1R (M52_ETM_BASE + 0x024U)
#define M52_ETM_TRCSTALLCTLR (M52_ETM_BASE + 0x02CU)
#define M52_ETM_TRCTSCTLR   (M52_ETM_BASE + 0x030U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define M52_ETM_TRCVICTLR   (M52_ETM_BASE + 0x080U)
#define ETM_LAR_KEY         0xC5ACCE55U
#define ETM_TRCSTATR_IDLE   (1U << 0)

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

    /* Unlock ITM, enable all stimulus ports, then enable the ITM ATB
     * interface and sync packets. */
    W32(M52_ITM_LAR, ETM_LAR_KEY);
    W32(M52_ITM_TER, 0xFFFFFFFFU);
    W32(M52_ITM_TCR, M52_ITM_TCR_VAL);

    /*
     * ETM-M52 programming sequence:
     * disable -> wait TRCSTATR.IDLE -> program required registers -> enable.
     * TRCSYNCPR is RO on M52 and must not be written.
     */
    W32(M52_ETM_LAR, ETM_LAR_KEY);
    W32(M52_ETM_TRCPRGCTLR, 0U);

    for (unsigned int i = 0U; i < 1000U; ++i) {
        if ((R32(M52_ETM_TRCSTATR) & ETM_TRCSTATR_IDLE) != 0U) {
            break;
        }
    }

    W32(M52_ETM_TRCCONFIGR, 0x000018C1U);
    W32(M52_ETM_TRCEVENTCTL0R, 0x00000000U);
    W32(M52_ETM_TRCEVENTCTL1R, 0x00000000U);
    W32(M52_ETM_TRCSTALLCTLR, 0x00000000U);
    W32(M52_ETM_TRCTSCTLR, 0x00000000U);
    W32(M52_ETM_TRCTRACEIDR, 0x00000002U);
    W32(M52_ETM_TRCVICTLR, 0x00000201U);
    W32(M52_ETM_TRCPRGCTLR, 1U);

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
