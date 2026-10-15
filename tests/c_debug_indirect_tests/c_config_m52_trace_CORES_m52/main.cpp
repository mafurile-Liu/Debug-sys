/*
 * c_config_m52_trace_CORES_m52/main.cpp
 *
 * Configure M52 ITM/ETM trace through the M52 AHB-AP debug window.
 *
 * This case uses the existing m52_ahbap_* helpers for all M52 PPB accesses.
 * It does not write PPB addresses directly and does not use <stdio.h>.
 */

#include "drv_common.h"
#include "drv_debug.h"

/* M52 PPB registers (M52 TRM). */
#define M52_CPUID           0xE000ED00U
#define M52_ITM_STIM(port)  (0xE0000000U + ((port) * 4U))
#define M52_ITM_TER         0xE0000E00U
#define M52_ITM_TPR         0xE0000E40U
#define M52_ITM_TCR         0xE0000E80U
#define M52_ITM_TCR_ATBID_SHIFT 16U
#define M52_ITM_TCR_ITMEN   (1U << 0)
#define M52_ITM_TCR_SYNCENA (1U << 2)
#define M52_ITM_TCR_VAL     ((1U << M52_ITM_TCR_ATBID_SHIFT) | \
                         M52_ITM_TCR_SYNCENA | M52_ITM_TCR_ITMEN)
#define M52_ETM_BASE        0xE0041000U
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCSTATR    (M52_ETM_BASE + 0x00CU)
#define M52_ETM_TRCCONFIGR  (M52_ETM_BASE + 0x010U)
#define M52_ETM_TRCEVENTCTL0R (M52_ETM_BASE + 0x020U)
#define M52_ETM_TRCEVENTCTL1R (M52_ETM_BASE + 0x024U)
#define M52_ETM_TRCSTALLCTLR (M52_ETM_BASE + 0x02CU)
#define M52_ETM_TRCTSCTLR   (M52_ETM_BASE + 0x030U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define M52_ETM_TRCVICTLR   (M52_ETM_BASE + 0x080U)
#define ETM_TRCSTATR_IDLE   (1U << 0)

static void m52_check_reg(const char *name,
                          uint32_t got,
                          uint32_t want,
                          uint32_t mask)
{
    c_uvm_info("%s = 0x%08x (want=0x%08x mask=0x%08x)",
               name, got, want, mask);

    if ((got & mask) != (want & mask)) {
        c_uvm_error("%s: readback mismatch got=0x%08x want=0x%08x mask=0x%08x",
                    name, got, want, mask);
    }
}

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

    /* Configure the M52 PPB access window before any M52 register access. */
    m52_ahbap_config();

    /* Verify the AHB-AP is present before relying on TAR/DRW accesses. */
    m52_check_reg("ahbap IDR", m52_ahbap_idr(), 0x54770008U, 0xFFFFFF00U);

    /* Basic sanity check that the AP path reaches the M52 CPU. */
    m52_check_reg("m52 CPUID", m52_ahbap_read(M52_CPUID),
                  0x630FD244U, 0xFFFFFFFFU);

    /* Enable M52 debug trace logic. */
    m52_ahbap_write(M52_DEMCR, M52_DEMCR_TRCENA);
    m52_check_reg("DEMCR", m52_ahbap_read(M52_DEMCR),
                  M52_DEMCR_TRCENA, M52_DEMCR_TRCENA);

    /* Enable all stimulus ports, then enable the ITM ATB interface. */
    m52_ahbap_write(M52_ITM_TPR, 0x0000000FU);
    m52_ahbap_write(M52_ITM_TER, 0xFFFFFFFFU);
    m52_ahbap_write(M52_ITM_TCR, M52_ITM_TCR_VAL);
    m52_check_reg("ITM_TPR", m52_ahbap_read(M52_ITM_TPR),
                  0x0000000FU, 0x0000000FU);
    m52_check_reg("ITM_TER", m52_ahbap_read(M52_ITM_TER),
                  0xFFFFFFFFU, 0xFFFFFFFFU);
    m52_check_reg("ITM_TCR", m52_ahbap_read(M52_ITM_TCR),
                  M52_ITM_TCR_VAL, M52_ITM_TCR_VAL);

    /*
     * ETM-M52 programming sequence:
     * disable -> wait TRCSTATR.IDLE -> program required registers -> enable.
     * TRCSYNCPR is RO on M52 and must not be written.
     */
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 0U);

    uint32_t etm_status = 0U;
    for (unsigned int i = 0U; i < 1000U; ++i) {
        etm_status = m52_ahbap_read(M52_ETM_TRCSTATR);
        if ((etm_status & ETM_TRCSTATR_IDLE) != 0U) {
            break;
        }
    }

    if ((etm_status & ETM_TRCSTATR_IDLE) == 0U) {
        c_uvm_error("ETM TRCSTATR.IDLE timeout, status=0x%08x", etm_status);
    }

    /* M52 does not implement Context ID/VMID tracing. */
    m52_ahbap_write(M52_ETM_TRCCONFIGR, 0x00001801U);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL0R, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL1R, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCSTALLCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTSCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTRACEIDR, 0x00000002U);
    m52_ahbap_write(M52_ETM_TRCVICTLR, 0x00010201U);
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 1U);

    m52_check_reg("ETM_TRCCONFIGR", m52_ahbap_read(M52_ETM_TRCCONFIGR),
                  0x00001801U, 0x00001801U);
    m52_check_reg("ETM_TRCEVENTCTL0R", m52_ahbap_read(M52_ETM_TRCEVENTCTL0R),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCEVENTCTL1R", m52_ahbap_read(M52_ETM_TRCEVENTCTL1R),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCSTALLCTLR", m52_ahbap_read(M52_ETM_TRCSTALLCTLR),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCTSCTLR", m52_ahbap_read(M52_ETM_TRCTSCTLR),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCTRACEIDR", m52_ahbap_read(M52_ETM_TRCTRACEIDR),
                  0x00000002U, 0x0000007FU);
    m52_check_reg("ETM_TRCVICTLR", m52_ahbap_read(M52_ETM_TRCVICTLR),
                  0x00010201U, 0x00010201U);
    m52_check_reg("ETM_TRCPRGCTLR", m52_ahbap_read(M52_ETM_TRCPRGCTLR),
                  0x00000001U, 0x00000001U);

    /*
     * ITM only emits ATB data when software writes a stimulus port. Keep this
     * loop tiny; it also provides enough data to exercise downstream flushing.
     */
    for (unsigned int i = 0U; i < 16U; ++i) {
        m52_ahbap_write(M52_ITM_STIM(0), 0xC0DE0000U + i);
    }

    {
        uint32_t stim_status = m52_ahbap_read(M52_ITM_STIM(0));
        c_uvm_info("ITM_STIM0 = 0x%08x (FIFOREADY=%0d)",
                   stim_status, stim_status & 1U);
        if ((stim_status & 1U) == 0U) {
            c_uvm_error("ITM_STIM0.FIFOREADY is not ready, status=0x%08x",
                        stim_status);
        }
    }

    c_uvm_info("%s", "m52 itm/etm trace enabled via AHB-AP");
    C_PASS();
COP_TEST_END
