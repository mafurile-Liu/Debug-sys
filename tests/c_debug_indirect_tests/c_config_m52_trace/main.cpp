/*
 * c_config_m52_trace/main.cpp
 *
 * Indirect-access-port case: configure the AHB-AP (m2 ahb_ap_m52) through
 * its debug-APB register windows, access the M52 via TAR/DRW, and enable
 * the M52 ITM + ETM trace output.
 *
 * Address scheme (dbg_address_mapping (1).xlsx, m2 ahb_ap_m52, 8KB block):
 *   external view 0x4A00_4000 : AP regs page0
 *       CSW @ +0xD00, TAR @ +0xD04, DRW @ +0xD0C, IDR @ +0xDFC
 *   internal view 0x4A00_5000 : AP regs page1
 *       DAR0-255 @ +0x000-0x3FC (direct window on TAR's 1KB base),
 *       mirrored CSW/TAR/DRW @ +0xD00/+0xD04/+0xD0C
 *   Convention: AP config via external view, M52 data access via the
 *   internal view DAR/DRW window.
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

/* ---- AHB-AP (m2 ahb_ap_m52) windows ---- */
#define AHBAP_EXT_BASE  0x4A004000U   /* external view: AP regs page0 */
#define AHBAP_INT_BASE  0x4A005000U   /* internal view: AP regs page1 (DAR0-255) */
#define AHBAP_CSW       (AHBAP_EXT_BASE + 0xD00U)
#define AHBAP_TAR       (AHBAP_EXT_BASE + 0xD04U)
#define AHBAP_IDR       (AHBAP_EXT_BASE + 0xDFCU)
#define AHBAP_INT_DRW   (AHBAP_INT_BASE  + 0xD0CU)   /* data via internal view */
#define AHBAP_INT_DAR0  (AHBAP_INT_BASE + 0x000U)

/* CSW fields (SoC-600 TRM 9.1.5 Table 9-6) */
#define AHBAP_CSW_HNONSEC  (1U << 30)
#define AHBAP_CSW_HPROT    (3U << 24)             /* privileged, data (reset) */
#define AHBAP_CSW_ADDRINC  (1U << 4)              /* single increment on DRW */
#define AHBAP_CSW_SIZE32   (2U)                   /* 32-bit */

/* ---- M52 PPB registers (M52 TRM 8.3, 18.2) ---- */
#define M52_CPUID   0xE000ED00U
#define M52_DHCSR   0xE000EDF0U
#define M52_DEMCR   0xE000EDFCU
#define M52_DEMCR_TRCENA   (1U << 24)
#define M52_CPUID_VAL 0x630FD244U   /* Arm China Cortex-M52 (verified in sim) */
#define M52_ITM_BASE 0xE0000000U
#define M52_ITM_TER  (M52_ITM_BASE + 0xE00U)
#define M52_ITM_TCR  (M52_ITM_BASE + 0xE80U)
#define M52_ITM_TCR_VAL  ((1U << 16) | (1U << 3) | 1U)  /* ATBID=1, SYNCENA, ITMEn */
#define M52_ETM_BASE 0xE0041000U
#define M52_ETM_LAR  (M52_ETM_BASE + 0xFB0U)
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define ETM_LAR_KEY  0xC5ACCE55U

/* one M52 32-bit access = TAR write + DRW data access (internal view) */
static void m52_write(uint32_t addr, uint32_t data)
{
    W32(AHBAP_TAR, addr);
    W32(AHBAP_INT_DRW, data);
}

static uint32_t m52_read(uint32_t addr)
{
    W32(AHBAP_TAR, addr);
    return R32(AHBAP_INT_DRW);
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* Route the trace path so M52 ITM/ETM output has somewhere to go:
     * funnel mask 0x07 = ports 0,1,2 (crash_dump + M52 ITM + M52 ETM -
     * confirm exact port numbers against the design) -> ETF -> ETR. */
    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   0x07U,
                   AON_SRAM_BASE_ADDR,
                   0x00010000U,
                   CATU_SLADDR_DEFAULT);

    /* ---- 1. Configure the AHB-AP (external view) ----
     * HNONSEC=1, HPROT=privileged-data, AddrInc=single, Size=32-bit. */
    W32(AHBAP_CSW, AHBAP_CSW_HNONSEC | AHBAP_CSW_HPROT |
                   AHBAP_CSW_ADDRINC | AHBAP_CSW_SIZE32);

    /* AP alive check: AHB-AP IDR (external view +0xDFC) */
    {
        uint32_t idr = R32(AHBAP_IDR);
        c_uvm_info("ahbap IDR = 0x%08x (TRM: 0x54770008)", idr);
    }

    /* ---- 2. M52 register access via internal view (TAR + DRW) ---- */
    /* CPUID: expect 0x630FD244 (Arm China Cortex-M52, verified in sim) */
    {
        uint32_t cpuid = m52_read(M52_CPUID);
        if (cpuid == M52_CPUID_VAL) {
            c_uvm_info("m52 cpuid ok: 0x%08x", cpuid);
        } else {
            c_uvm_error("m52 cpuid mismatch: got 0x%08x want 0x630FD244", cpuid);
        }
    }

    {
        uint32_t dhcsr = m52_read(M52_DHCSR);
        c_uvm_info("m52 dhcsr = 0x%08x", dhcsr);
    }

    /* ---- 3. Enable M52 ITM + ETM trace output ---- */
    /* DEMCR.TRCENA = 1: must be set before programming/using the ITM
     * (M52 TRM 18.2) and it gates the ETM. */
    m52_write(M52_DEMCR, M52_DEMCR_TRCENA);

    /* ITM (M52 TRM 18.2): no LAR (not implemented); TCR = ITMEn | SYNCENA |
     * ATBID=1; TER = all 32 stimulus ports enabled. */
    m52_write(M52_ITM_TCR, M52_ITM_TCR_VAL);
    m52_write(M52_ITM_TER, 0xFFFFFFFFU);
    {
        uint32_t tcr = m52_read(M52_ITM_TCR);
        c_uvm_info("itm tcr = 0x%08x (expect 0x00010009)", tcr);
    }

    /* ETM (ETMv4.5 ETM-M52): unlock LAR (if implemented), trace ID = 2,
     * then TRCPRGCTLR.EN = 1. TRM: Arm China CoreSight ETM-M52 TRM. */
    m52_write(M52_ETM_LAR, ETM_LAR_KEY);
    m52_write(M52_ETM_TRCTRACEIDR, 0x00000002U);
    m52_write(M52_ETM_TRCPRGCTLR, 0x00000001U);
    {
        uint32_t pgctlr = m52_read(M52_ETM_TRCPRGCTLR);
        c_uvm_info("etm prgctlr = 0x%08x (expect 0x1)", pgctlr);
    }

    c_uvm_info("%s", "m52 itm/etm trace output enabled");
    C_PASS();
CPU_TEST_END