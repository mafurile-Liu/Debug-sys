/*
 * c_config_m52_trace/main.cpp
 *
 * ACPU-hosted indirect-access case: configure the AHB-AP (m2 ahb_ap_m52)
 * through its debug-APB register windows, access the M52 via TAR/DRW, and
 * enable M52 ITM output and ETM event-trace output.
 *
 * Address scheme (dbg_address_mapping (1).xlsx, m2 ahb_ap_m52, 8KB block):
 *   internal view 0x4A00_5000 : AP regs page1
 *       CSW @ +0xD00, TAR @ +0xD04, DRW @ +0xD0C, IDR @ +0xDFC
 *   All AHB-AP accesses (CSW/TAR/DRW) go through the internal view
 *
 * M52 PPB map (M52 TRM 8.3, Table 8-3/8-4):
 *   ITM 0xE000_0000 (TER 0xE00, TCR 0xE80; no LAR - not implemented)
 *   SCS 0xE000_E000 (CPUID 0xED00, DHCSR 0xEDF0, DEMCR 0xEDFC)
 *   ETM 0xE004_1000 (ETMv4.5 ETM-M52: TRCPRGCTLR 0x004, TRCTRACEIDR 0x200,
 *   LAR 0xFB0)
 *   DEMCR.TRCENA must be set before programming/using the ITM (TRM 18.2).
 */

#include <stdio.h>
#include "drv_common.h"
#include "drv_debug.h"
#include "coresight_trace_regs.h"   /* AON_SRAM_BASE_ADDR, CATU_SLADDR_DEFAULT */

/* ---- M52 PPB registers (M52 TRM 8.3, 18.2) ---- */
#define M52_CPUID   0xE000ED00U
#define M52_DHCSR   0xE000EDF0U
#define M52_DEMCR   0xE000EDFCU
#define M52_DEMCR_TRCENA   (1U << 24)
#define M52_CPUID_VAL 0x630FD244U   /* Arm China Cortex-M52 (verified in sim) */
#define M52_ITM_BASE 0xE0000000U
#define M52_ITM_STIM(port) (M52_ITM_BASE + ((port) * 4U))
#define M52_ITM_TER  (M52_ITM_BASE + 0xE00U)
#define M52_ITM_TPR  (M52_ITM_BASE + 0xE40U)
#define M52_ITM_TCR  (M52_ITM_BASE + 0xE80U)
#define M52_ITM_TCR_ATBID_SHIFT 16U
#define M52_ITM_TCR_ITMEN   (1U << 0)
#define M52_ITM_TCR_SYNCENA (1U << 2)
#define M52_ITM_TCR_VAL     ((1U << M52_ITM_TCR_ATBID_SHIFT) | \
                         M52_ITM_TCR_SYNCENA | M52_ITM_TCR_ITMEN)
#define M52_ETM_BASE 0xE0041000U
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCSTATR    (M52_ETM_BASE + 0x00CU)
#define M52_ETM_TRCCONFIGR  (M52_ETM_BASE + 0x010U)
#define M52_ETM_TRCEVENTCTL0R (M52_ETM_BASE + 0x020U)
#define M52_ETM_TRCEVENTCTL1R (M52_ETM_BASE + 0x024U)
#define M52_ETM_TRCSTALLCTLR (M52_ETM_BASE + 0x02CU)
#define M52_ETM_TRCTSCTLR   (M52_ETM_BASE + 0x030U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define M52_ETM_TRCRSCTLR2  (M52_ETM_BASE + 0x208U)
#define M52_ETM_TRCCNTRLDVR0 (M52_ETM_BASE + 0x140U)
#define M52_ETM_TRCVICTLR   (M52_ETM_BASE + 0x080U)
#define M52_ETM_TRCPDCR     (M52_ETM_BASE + 0x310U)
#define M52_ETM_TRCPDSR     (M52_ETM_BASE + 0x314U)

#define ETM_TRCSTATR_IDLE    (1U << 0)
#define ETM_TRCSTATR_PMSTABLE (1U << 1)
#define ETM_TRCPDCR_PU      (1U << 3)
#define ETM_TRCPDSR_POWER   (1U << 0)

/*
 * Use the reduced-function counter to make event0 periodic instead of
 * continuously asserted. Resource selector 2 selects counter0-at-zero.
 */
#define ETM_RSCTLR2_COUNTER0_AT_ZERO 0x00020000U
#define ETM_EVENT0_SELECT_RS2        0x00000002U
#define ETM_EVENT0_INSTEN            0x00000001U
#define ETM_EVENT1R_ATB              0x00000800U
#define ETM_EVENT1R_LPOVERRIDE       0x00001000U
#define ETM_EVENT1R_VAL              (ETM_EVENT1R_LPOVERRIDE | ETM_EVENT1R_ATB | ETM_EVENT0_INSTEN)
#define ETM_VIEWINST_EVENT0_ACTIVE   0x00090A00U /* Thread+Handler, TRCERR, SSSTATUS, EVENT0 */

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

#define AON_SRAM_CHECK_BYTES      0x00000100U

static void aon_sram_trace_data_check(void)
{
    uint32_t off;
    uint32_t got;

    for (off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        got = R32((uintptr_t)(AON_SRAM_BASE_ADDR + off));
        if (got != 0U) {
            c_uvm_info("AON SRAM trace check: first nonzero @0x%08x=0x%08x",
                       AON_SRAM_BASE_ADDR + off, got);
            return;
        }
    }

    c_uvm_error("%s", "AON SRAM trace check: no nonzero data found");
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /*
     * Clear only the checked window before configuring the trace path so the
     * final SRAM check cannot be fooled by stale trace data.
     */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)(AON_SRAM_BASE_ADDR + off), 0U);
    }

    /* Route the trace path so M52 ITM/ETM output has somewhere to go:
     * funnel mask 0x07 = ports 0,1,2 (crash_dump + M52 ITM + M52 ETM -
     * confirm exact port numbers against the design) -> ETF -> ETR. */
    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   0x07U,
                   AON_SRAM_BASE_ADDR,
                   0x00010000U,
                   CATU_SLADDR_DEFAULT);

    /* ---- 1. Configure the M52 AHB-AP for Secure-privileged access. ---- */
    m52_ahbap_config();

    /* AP alive check: AHB-AP IDR (external view +0xDFC) */
    m52_check_reg("ahbap IDR", m52_ahbap_idr(),
                  0x54770008U, 0xFFFFFF00U);

    /* ---- 2. M52 register access via AHB-AP TAR/DRW ---- */
    /* CPUID: expect 0x630FD244 (Arm China Cortex-M52, verified in sim) */
    m52_check_reg("m52 CPUID", m52_ahbap_read(M52_CPUID),
                  M52_CPUID_VAL, 0xFFFFFFFFU);

    {
        uint32_t dhcsr = m52_ahbap_read(M52_DHCSR);
        c_uvm_info("m52 dhcsr = 0x%08x", dhcsr);
    }

    /* ---- 3. Enable M52 ITM + ETM trace output ---- */
    /* DEMCR.TRCENA = 1: must be set before programming/using the ITM
     * (M52 TRM 18.2) and it gates the ETM. */
    m52_ahbap_write(M52_DEMCR, M52_DEMCR_TRCENA);
    m52_check_reg("DEMCR", m52_ahbap_read(M52_DEMCR),
                  M52_DEMCR_TRCENA, M52_DEMCR_TRCENA);

    /* ITM (M52 TRM 18.2): no LAR (not implemented); TCR = ITMEn | SYNCENA |
     * ATBID=1; TER = all 32 stimulus ports enabled. */
    m52_ahbap_write(M52_ITM_TPR, 0x0000000FU);
    m52_ahbap_write(M52_ITM_TCR, M52_ITM_TCR_VAL);
    m52_ahbap_write(M52_ITM_TER, 0xFFFFFFFFU);
    m52_check_reg("ITM_TPR", m52_ahbap_read(M52_ITM_TPR),
                  0x0000000FU, 0x0000000FU);
    m52_check_reg("ITM_TER", m52_ahbap_read(M52_ITM_TER),
                  0xFFFFFFFFU, 0xFFFFFFFFU);
    m52_check_reg("ITM_TCR", m52_ahbap_read(M52_ITM_TCR),
                  M52_ITM_TCR_VAL, M52_ITM_TCR_VAL);

    /* ETM must be powered before trace registers are programmed. */
    m52_ahbap_write(M52_ETM_TRCPDCR, ETM_TRCPDCR_PU);
    m52_check_reg("ETM_TRCPDCR", m52_ahbap_read(M52_ETM_TRCPDCR),
                  ETM_TRCPDCR_PU, ETM_TRCPDCR_PU);
    m52_check_reg("ETM_TRCPDSR", m52_ahbap_read(M52_ETM_TRCPDSR),
                  ETM_TRCPDSR_POWER, ETM_TRCPDSR_POWER);

    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 0U);

    /*
     * The ETM programmers model must be stable before any trace registers are
     * programmed. Otherwise some register writes can be ignored.
     */
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
    }
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
     * ETM (ETMv4.5 ETM-M52): use a periodic event element, not instruction
     * trace, so ETM can still emit ATB packets while M52 is stalled on a
     * fetch error. The reduced-function counter0 decrements on every core
     * clock and self-reloads when it reaches zero.
     */
    m52_ahbap_write(M52_ETM_TRCCNTRLDVR0, 0x00000010U);
    m52_ahbap_write(M52_ETM_TRCRSCTLR2, ETM_RSCTLR2_COUNTER0_AT_ZERO);
    m52_ahbap_write(M52_ETM_TRCCONFIGR, 0x00001801U);
    m52_ahbap_write(M52_ETM_TRCSTALLCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTSCTLR, 0x00000000U);
    m52_ahbap_write(M52_ETM_TRCTRACEIDR, 0x00000002U);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL0R, ETM_EVENT0_SELECT_RS2);
    m52_ahbap_write(M52_ETM_TRCEVENTCTL1R, ETM_EVENT1R_VAL);
    m52_ahbap_write(M52_ETM_TRCVICTLR, ETM_VIEWINST_EVENT0_ACTIVE);
    m52_ahbap_write(M52_ETM_TRCPRGCTLR, 0x00000001U);

    m52_check_reg("ETM_TRCCONFIGR", m52_ahbap_read(M52_ETM_TRCCONFIGR),
                  0x00001801U, 0x00001801U);
    m52_check_reg("ETM_TRCEVENTCTL0R", m52_ahbap_read(M52_ETM_TRCEVENTCTL0R),
                  ETM_EVENT0_SELECT_RS2, 0x000000FFU);
    m52_check_reg("ETM_TRCEVENTCTL1R", m52_ahbap_read(M52_ETM_TRCEVENTCTL1R),
                  ETM_EVENT1R_VAL, 0x00001801U);
    m52_check_reg("ETM_TRCRSCTLR2", m52_ahbap_read(M52_ETM_TRCRSCTLR2),
                  ETM_RSCTLR2_COUNTER0_AT_ZERO, 0x000300FFU);
    m52_check_reg("ETM_TRCCNTRLDVR0", m52_ahbap_read(M52_ETM_TRCCNTRLDVR0),
                  0x00000010U, 0x0000FFFFU);
    m52_check_reg("ETM_TRCVICTLR", m52_ahbap_read(M52_ETM_TRCVICTLR),
                  ETM_VIEWINST_EVENT0_ACTIVE, 0x00090A00U);
    m52_check_reg("ETM_TRCPRGCTLR", m52_ahbap_read(M52_ETM_TRCPRGCTLR),
                  0x00000001U, 0x00000001U);

    /*
     * ITM emits ATB data when software writes a stimulus port. This works
     * from the debugger/AP path too and provides a short trace burst.
     */
    for (unsigned int i = 0U; i < 16U; ++i) {
        m52_ahbap_write(M52_ITM_STIM(0), 0xC0DE0000U + i);
    }

    aon_trace_flush();
    delay_us(1);

    {
        uint32_t stim_status = m52_ahbap_read(M52_ITM_STIM(0));
        c_uvm_info("ITM_STIM0 = 0x%08x (FIFOREADY=%0d)",
                   stim_status, stim_status & 1U);
        if ((stim_status & 1U) == 0U) {
            c_uvm_error("ITM_STIM0.FIFOREADY is not ready, status=0x%08x",
                        stim_status);
        }
    }

    /*
     * Weak sanity check only. Once the M52 ITM/ETM packet layout is decoded,
     * replace this with an explicit packet/payload check.
     */
    aon_sram_trace_data_check();

    c_uvm_info("%s", "m52 itm/etm trace enabled via AHB-AP");
    C_PASS();
CPU_TEST_END


