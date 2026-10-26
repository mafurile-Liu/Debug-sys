/*
 * c_config_m52_trace_ETM_CORES_m52/main.cpp
 *
 * M52-hosted ETM-only trace smoke case.
 *
 * This case intentionally does not program ITM. It configures the M52 ETM
 * through the M52 AHB-AP debug window and uses the AON trace tree as the
 * trace sink. The final AON SRAM check is therefore an ETM-only check.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug_small.h"
#include "coresight_trace_regs.h"

/* M52 PPB/SCS registers. */
#define M52_CPUID              0xE000ED00U
#define M52_CPUID_VAL          0x630FD244U
#define M52_DEMCR              0xE000EDFCU
#define M52_DEMCR_TRCENA       (1U << 24)

/* M52 ETM registers (ETM-M52 TRM). */
#define M52_ETM_BASE           0xE0041000U
#define M52_ETM_TRCPRGCTLR     (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCSTATR       (M52_ETM_BASE + 0x00CU)
#define M52_ETM_TRCCONFIGR     (M52_ETM_BASE + 0x010U)
#define M52_ETM_TRCEVENTCTL0R  (M52_ETM_BASE + 0x020U)
#define M52_ETM_TRCEVENTCTL1R  (M52_ETM_BASE + 0x024U)
#define M52_ETM_TRCSTALLCTLR   (M52_ETM_BASE + 0x02CU)
#define M52_ETM_TRCTSCTLR      (M52_ETM_BASE + 0x030U)
#define M52_ETM_TRCTRACEIDR    (M52_ETM_BASE + 0x200U)
#define M52_ETM_TRCVICTLR      (M52_ETM_BASE + 0x080U)
#define M52_ETM_TRCPDCR        (M52_ETM_BASE + 0x310U)
#define M52_ETM_TRCPDSR        (M52_ETM_BASE + 0x314U)

#define ETM_TRCSTATR_IDLE      (1U << 0)
#define ETM_TRCPDCR_PU         (1U << 3)
#define ETM_TRCPDSR_POWER      (1U << 0)

/*
 * ETM-M52 ViewInst:
 *   bit[19] Handler mode
 *   bit[16] Thread mode
 *   bit[9]  SSSTATUS = started
 *   [7:0]   EVENT    = 1 (fixed TRUE in the M52 resource map)
 */
#define ETM_VIEWINST_ACTIVE    0x00090201U

/* ETM is connected to AON funnel slave port 2. */
#define AON_M52_ETM_FUNNEL_PORT 2U
#define AON_M52_ETM_FUNNEL_MASK (1U << AON_M52_ETM_FUNNEL_PORT)

#define AON_TRACE_BUF_ADDR     AON_SRAM_BASE_ADDR
#define AON_TRACE_BUF_SIZE     0x00010000U
#define AON_SRAM_CHECK_BYTES   0x00000100U

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

static void aon_sram_trace_data_check(void)
{
    uint32_t off;
    uint32_t got;

    for (off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        got = R32((uintptr_t)(AON_TRACE_BUF_ADDR + off));
        if (got != 0U) {
            c_uvm_info("AON SRAM ETM check: first nonzero @0x%08x=0x%08x",
                       AON_TRACE_BUF_ADDR + off, got);
            return;
        }
    }

    c_uvm_error("%s", "AON SRAM ETM check: no nonzero data found");
}

COP_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    /*
     * Clear the checked SRAM window first so the final check cannot be fooled
     * by stale trace data. Only the ETM funnel port is enabled in this case.
     */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)(AON_TRACE_BUF_ADDR + off), 0U);
    }

    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   AON_M52_ETM_FUNNEL_MASK,
                   AON_TRACE_BUF_ADDR,
                   AON_TRACE_BUF_SIZE,
                   CATU_SLADDR_DEFAULT);

    m52_ahbap_config();
    m52_check_reg("ahbap IDR", m52_ahbap_idr(), 0x54770008U, 0xFFFFFF00U);
    m52_check_reg("m52 CPUID", m52_ahbap_read(M52_CPUID),
                  M52_CPUID_VAL, 0xFFFFFFFFU);

    m52_ahbap_write(M52_DEMCR, M52_DEMCR_TRCENA);
    m52_check_reg("DEMCR", m52_ahbap_read(M52_DEMCR),
                  M52_DEMCR_TRCENA, M52_DEMCR_TRCENA);

    /* Power ETM before programming its trace registers. */
    m52_ahbap_write(M52_ETM_TRCPDCR, ETM_TRCPDCR_PU);
    m52_check_reg("ETM_TRCPDCR", m52_ahbap_read(M52_ETM_TRCPDCR),
                  ETM_TRCPDCR_PU, ETM_TRCPDCR_PU);
    m52_check_reg("ETM_TRCPDSR", m52_ahbap_read(M52_ETM_TRCPDSR),
                  ETM_TRCPDSR_POWER, ETM_TRCPDSR_POWER);

    /* Disable ETM and wait until the programmers model is idle. */
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 0U);
    {
        uint32_t etm_status = 0U;
        for (unsigned int i = 0U; i < 100U; ++i) {
            etm_status = m52_ahbap_read(M52_ETM_TRCSTATR);
            if ((etm_status & ETM_TRCSTATR_IDLE) != 0U) {
                break;
            }
        }

        if ((etm_status & ETM_TRCSTATR_IDLE) == 0U) {
            c_uvm_error("ETM TRCSTATR.IDLE timeout, status=0x%08x",
                        etm_status);
        }
    }

    /*
     * Keep this case simple: use normal instruction trace with ViewInst
     * always active. No event/counter configuration is used here.
     */
    m52_ahbap_write(M52_ETM_TRCCONFIGR, 0x00001801U);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL0R, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL1R, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCSTALLCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTSCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTRACEIDR, 0x00000002U);
    m52_ahbap_write(M52_ETM_TRCVICTLR, ETM_VIEWINST_ACTIVE);
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 1U);

    m52_check_reg("ETM_TRCCONFIGR", m52_ahbap_read(M52_ETM_TRCCONFIGR),
                  0x00001801U, 0x00001801U);
    m52_check_reg("ETM_TRCEVENTCTL0R",
                  m52_ahbap_read(M52_ETM_TRCEVENTCTL0R),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCEVENTCTL1R",
                  m52_ahbap_read(M52_ETM_TRCEVENTCTL1R),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCSTALLCTLR",
                  m52_ahbap_read(M52_ETM_TRCSTALLCTLR),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCTSCTLR", m52_ahbap_read(M52_ETM_TRCTSCTLR),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCTRACEIDR", m52_ahbap_read(M52_ETM_TRCTRACEIDR),
                  0x00000002U, 0x0000007FU);
    m52_check_reg("ETM_TRCVICTLR", m52_ahbap_read(M52_ETM_TRCVICTLR),
                  ETM_VIEWINST_ACTIVE, ETM_VIEWINST_ACTIVE);
    m52_check_reg("ETM_TRCPRGCTLR", m52_ahbap_read(M52_ETM_TRCPRGCTLR),
                  0x00000001U, 0x00000001U);

    /*
     * Generate some instruction activity after ETM is enabled. This is not
     * ITM traffic; it is only used to ensure the ETM instruction trace has
     * data before flushing the AON trace path.
     */
    {
        volatile uint32_t spin = 0U;
        for (uint32_t i = 0U; i < 64U; ++i) {
            spin += i;
        }
        c_uvm_info("ETM activity spin done, value=0x%08x", spin);
    }

    aon_trace_flush();
    delay_us(1);

    /*
     * Since ITM is not configured in this case, any nonzero trace data in the
     * checked AON SRAM window must have come from ETM.
     */
    aon_sram_trace_data_check();

    c_uvm_info("%s", "m52 ETM-only trace enabled via AHB-AP");
    C_PASS();
COP_TEST_END
