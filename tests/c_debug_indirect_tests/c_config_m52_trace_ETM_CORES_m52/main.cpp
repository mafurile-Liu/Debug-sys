/*
 * c_config_m52_trace_ETM_CORES_m52/main.cpp
 *
 * ACPU/M52 co-executed ETM-only trace smoke case.
 *
 * ACPU configures the AON trace path and the M52 ETM. The M52 COP section
 * waits for ACPU, runs a minimal instruction burst, and reports completion.
 * This case intentionally does not program ITM, so the final AON SRAM check
 * is an ETM-only check.
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
#define M52_ETM_TRCTRACEIDR    (M52_ETM_BASE + 0x040U)
#define M52_ETM_TRCVICTLR      (M52_ETM_BASE + 0x080U)
#define M52_ETM_TRCVIPCSSCTLR  (M52_ETM_BASE + 0x08CU)
#define M52_ETM_TRCPDCR        (M52_ETM_BASE + 0x310U)
#define M52_ETM_TRCPDSR        (M52_ETM_BASE + 0x314U)
#define M52_ETM_TRCLAR         (M52_ETM_BASE + 0xFB0U)
#define M52_ETM_TRCLSR         (M52_ETM_BASE + 0xFB4U)
#define M52_ETM_TRCDEVARCH     (M52_ETM_BASE + 0xFBCU)
#define M52_ETM_TRCAUTHSTATUS  (M52_ETM_BASE + 0xFB8U)
#define M52_ETM_TRCIDR1        (M52_ETM_BASE + 0x1E4U)
#define M52_ETM_TRCDEVTYPE     (M52_ETM_BASE + 0xFCCU)

#define ETM_TRCSTATR_IDLE      (1U << 0)
#define ETM_TRCSTATR_PMSTABLE  (1U << 1)
#define ETM_TRCPDCR_PU         (1U << 3)
#define ETM_TRCPDSR_POWER      (1U << 0)

/*
 * ETM-M52 ViewInst:
 *   bit[19] Handler mode
 *   bit[16] Thread mode
 *   bit[9]  SSSTATUS = started
 *   [7:0]   EVENT    = 1 (fixed TRUE in the M52 resource map)
 */
#define ETM_VIEWINST_ACTIVE    0x00090A01U /* Thread+Handler, TRCERR, SSSTATUS, fixed TRUE */
#define ETM_EVENT1R_LPOVERRIDE 0x00001000U

/* ETM is connected to AON funnel slave port 2. */
#define AON_M52_ETM_FUNNEL_PORT 2U
#define AON_M52_ETM_FUNNEL_MASK (1U << AON_M52_ETM_FUNNEL_PORT)

#define AON_TRACE_BUF_ADDR     AON_SRAM_BASE_ADDR
#define AON_TRACE_BUF_SIZE     0x00010000U
#define AON_SRAM_CHECK_BYTES   0x00000100U

/*
 * Put the CPU<->M52 handshake just outside the ETR buffer so the handshake
 * writes cannot be mistaken for trace data in the checked SRAM window.
 */
#define AON_M52_START_FLAG_ADDR (AON_TRACE_BUF_ADDR + AON_TRACE_BUF_SIZE)
#define AON_M52_DONE_FLAG_ADDR  (AON_TRACE_BUF_ADDR + AON_TRACE_BUF_SIZE + 4U)
#define AON_M52_START_FLAG      0xC0DE0001U
#define AON_M52_DONE_FLAG       0xC0DE0002U

COP_TEST_START
    /*
     * Keep the M52 side minimal: wait until ACPU has enabled ETM, execute a
     * tiny bounded instruction burst, then report completion.
     */
    while (R32((uintptr_t)AON_M52_START_FLAG_ADDR) != AON_M52_START_FLAG) {
    }

    {
        volatile uint32_t spin = 0U;
        for (uint32_t i = 0U; i < 16U; ++i) {
            spin += i;
        }
    }

    W32((uintptr_t)AON_M52_DONE_FLAG_ADDR, AON_M52_DONE_FLAG);
    COP_C_PASS();
COP_TEST_END

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

static void m52_etm_identity_check(void)
{
    uint32_t devarch = m52_ahbap_read(M52_ETM_TRCDEVARCH);
    uint32_t devtype = m52_ahbap_read(M52_ETM_TRCDEVTYPE);
    uint32_t idr1 = m52_ahbap_read(M52_ETM_TRCIDR1);
    uint32_t auth = m52_ahbap_read(M52_ETM_TRCAUTHSTATUS);

    c_uvm_info(
        "ETM identity: DEVARCH=0x%08x DEVTYPE=0x%08x IDR1=0x%08x AUTH=0x%08x",
        devarch, devtype, idr1, auth);

    if (devarch != 0x47754A13U) {
        c_uvm_error("ETM DEVARCH mismatch: got=0x%08x want=0x47754A13",
                    devarch);
    }
    if (devtype != 0x00000013U) {
        c_uvm_error("ETM DEVTYPE mismatch: got=0x%08x want=0x00000013",
                    devtype);
    }
    if ((idr1 & 0xFFFFFFF0U) != 0x4100F450U) {
        c_uvm_error("ETM IDR1 mismatch: got=0x%08x want=0x4100F45x", idr1);
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

CPU_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    /*
     * Clear the checked SRAM window and both handshake flags first. This
     * prevents stale flags from letting M52 run before ETM is enabled, and
     * keeps the final SRAM check from being fooled by stale trace data.
     */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)(AON_TRACE_BUF_ADDR + off), 0U);
    }
    W32((uintptr_t)AON_M52_START_FLAG_ADDR, 0U);
    W32((uintptr_t)AON_M52_DONE_FLAG_ADDR, 0U);

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

    {
        uint32_t pdsr = 0U;
        for (unsigned int i = 0U; i < 100U; ++i) {
            pdsr = m52_ahbap_read(M52_ETM_TRCPDSR);
            if ((pdsr & ETM_TRCPDSR_POWER) != 0U) {
                break;
            }
        }

        if ((pdsr & ETM_TRCPDSR_POWER) == 0U) {
            c_uvm_error("ETM TRCPDSR.POWER timeout, status=0x%08x", pdsr);
        } else {
            c_uvm_info("ETM TRCPDSR=0x%08x", pdsr);
        }
    }
    m52_etm_identity_check();

    {
        uint32_t lsr = m52_ahbap_read(M52_ETM_TRCLSR);
        c_uvm_info("ETM TRCLSR before unlock=0x%08x", lsr);
        m52_ahbap_write(M52_ETM_TRCLAR, 0xC5ACCE55U);
        lsr = m52_ahbap_read(M52_ETM_TRCLSR);
        c_uvm_info("ETM TRCLSR after unlock=0x%08x", lsr);
        if ((lsr & 0x2U) != 0U) {
            c_uvm_error("ETM software lock is still set, LSR=0x%08x", lsr);
        }
    }

    /* Disable ETM and wait until the programmers model is stable/idle. */
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 0U);
    m52_check_reg("ETM_TRCPRGCTLR(disabled)",
                  m52_ahbap_read(M52_ETM_TRCPRGCTLR),
                  0x00000000U, 0x00000001U);
    {
        uint32_t etm_status = 0U;

        for (unsigned int i = 0U; i < 100U; ++i) {
            etm_status = m52_ahbap_read(M52_ETM_TRCSTATR);
            if ((etm_status & ETM_TRCSTATR_PMSTABLE) != 0U) {
                break;
            }
        }

        if ((etm_status & ETM_TRCSTATR_PMSTABLE) == 0U) {
            c_uvm_error("ETM TRCSTATR.PMSTABLE timeout, status=0x%08x",
                        etm_status);
        }

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
    m52_ahbap_write(M52_ETM_TRCEVENTCTL1R, ETM_EVENT1R_LPOVERRIDE);
    m52_ahbap_write(M52_ETM_TRCSTALLCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTSCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTRACEIDR, 0x00000002U);
    {
        uint32_t trace_id = m52_ahbap_read(M52_ETM_TRCTRACEIDR);
        c_uvm_info("ETM trace ID while disabled=0x%08x", trace_id);
        if ((trace_id & 0x0000007FU) != 0x00000002U) {
            c_uvm_error("ETM trace ID did not stick while disabled: got=0x%08x",
                        trace_id);
        }
    }
    m52_ahbap_write(M52_ETM_TRCVIPCSSCTLR, 0x00000000U);
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
    {
        uint32_t trace_id = m52_ahbap_read(M52_ETM_TRCTRACEIDR);
        c_uvm_info("ETM trace ID while enabled=0x%08x", trace_id);
    }
    m52_check_reg("ETM_TRCVICTLR", m52_ahbap_read(M52_ETM_TRCVICTLR),
                  ETM_VIEWINST_ACTIVE, ETM_VIEWINST_ACTIVE);
    m52_check_reg("ETM_TRCVIPCSSCTLR",
                  m52_ahbap_read(M52_ETM_TRCVIPCSSCTLR),
                  0x00000000U, 0x00000000U);
    m52_check_reg("ETM_TRCPRGCTLR", m52_ahbap_read(M52_ETM_TRCPRGCTLR),
                  0x00000001U, 0x00000001U);

    /*
     * Give the M52 polling loop time to run while ETM is enabled. This keeps
     * the M52 COP code itself minimal while still generating enough trace.
     */
    delay_us(100);
    {
        uint32_t etm_status = m52_ahbap_read(M52_ETM_TRCSTATR);
        c_uvm_info("ETM status after enable=0x%08x", etm_status);
    }

    /*
     * Let the minimal M52 COP code run while ETM is active, then flush the
     * ETM-only trace path.
     */
    W32((uintptr_t)AON_M52_START_FLAG_ADDR, AON_M52_START_FLAG);
    {
        uint32_t done = 0U;
        uint32_t timeout = 0U;

        for (timeout = 0U; timeout < 100000U; ++timeout) {
            done = R32((uintptr_t)AON_M52_DONE_FLAG_ADDR);
            if (done == AON_M52_DONE_FLAG) {
                break;
            }
        }

        if (done != AON_M52_DONE_FLAG) {
            c_uvm_error("%s", "M52 ETM activity did not complete");
        }
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
CPU_TEST_END
