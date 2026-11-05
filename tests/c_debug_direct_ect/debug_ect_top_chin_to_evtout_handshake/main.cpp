/*
 * debug_ect_top_chin_to_evtout_handshake/main.cpp
 *
 * Program direct CTM-top-channel to AON CTI output mappings for the
 * handshake event outputs:
 *
 *   channel[7]  -> event_out[7]  / HiFi CrossTriggerIn
 *   channel[8]  -> event_out[8]  / HiFi BreakIn
 *   channel[14] -> event_out[14] / TBU pmusnapshot_req
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define ECT_TOP_HANDSHAKE_CTI_BASE  AON_CTI_BASE
#define ECT_TOP_HANDSHAKE_CH_MASK   0x4180U

/*
 * TBU MMU L1 PMCG registers.  Arm MMU L1 TRM places PMCG page0 at offset
 * 0x02000.  SMMUv3 architecture offsets from SMMUv3_PMCG:
 *   CFGR = 0xE00, CAPR = 0xD88, CR = 0xE04.
 */
#ifndef ECT_TBU_BASE
#define ECT_TBU_BASE               0x00000000U /* TODO: fill TBU base later */
#endif
#define TBU_PMCG_PAGE0            0x02000U
#define TBU_PMCG_CFGR             (TBU_PMCG_PAGE0 + 0x0E00U)
#define TBU_PMCG_CAPR             (TBU_PMCG_PAGE0 + 0x0D88U)
#define TBU_PMCG_CR               (TBU_PMCG_PAGE0 + 0x0E04U)
#define SMMU_PMCG_CFGR_CAPTURE     (1U << 22)
#define SMMU_PMCG_CR_ENABLE        (1U << 0)

static void ect_top_hs_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_TOP_HANDSHAKE_CTI_BASE + offset), value);
}

static uint32_t ect_top_hs_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_TOP_HANDSHAKE_CTI_BASE + offset));
}

static int ect_top_hs_is_mapped(uint32_t output)
{
    return (output == 7U) || (output == 8U) || (output == 14U);
}

static void ect_top_hs_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t i;
    uint32_t outen;

    ctrl = ect_top_hs_read(CTI_CONTROL);
    c_uvm_info("ect top handshake: CONTROL before config = 0x%08x", ctrl);
    ect_top_hs_write(CTI_CONTROL, 0U);

    /* channel[i] -> event_out[i] for handshake outputs only */
    for (i = 0U; i < 15U; ++i) {
        if (ect_top_hs_is_mapped(i)) {
            ect_top_hs_write(CTI_OUTEN(i), (1U << i));
        }
    }

    /* Only handshake channels pass the gate. */
    gate = ECT_TOP_HANDSHAKE_CH_MASK;
    ect_top_hs_write(CTI_GATE, gate);

    ect_top_hs_write(CTI_CONTROL, CTI_CONTROL_EN);

    ctrl = ect_top_hs_read(CTI_CONTROL);
    gate = ect_top_hs_read(CTI_GATE);

    c_uvm_info("ect top handshake: CONTROL=0x%08x GATE=0x%08x", ctrl, gate);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != ECT_TOP_HANDSHAKE_CH_MASK) {
        c_uvm_error("%s", "ect top handshake: CTI route readback mismatch");
    }

    for (i = 0U; i < 15U; ++i) {
        if (!ect_top_hs_is_mapped(i)) {
            continue;
        }
        outen = ect_top_hs_read(CTI_OUTEN(i));
        if (outen != (1U << i)) {
            c_uvm_error("ect top handshake: OUTEN%0d mismatch = 0x%08x", i, outen);
        }
    }
}

static void tbu_pmcg_configure(void)
{
#if (ECT_TBU_BASE != 0U)
    uint32_t cfgr = R32(ECT_TBU_BASE + TBU_PMCG_CFGR);

    if ((cfgr & SMMU_PMCG_CFGR_CAPTURE) == 0U) {
        c_uvm_error("tbu pmcg: CAPTURE not supported, CFGR=0x%08x", cfgr);
        return;
    }

    /* The wired req already performs CAPR.CAPTURE; enable the PMCG counters. */
    W32(ECT_TBU_BASE + TBU_PMCG_CR, SMMU_PMCG_CR_ENABLE);
    c_uvm_info("tbu pmcg: CFGR=0x%08x CR enabled, CAPR=0x%08x",
               cfgr, TBU_PMCG_CAPR);
#else
    c_uvm_info("%s", "tbu pmcg: ECT_TBU_BASE is reserved; skipping TBU setup");
#endif
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    hifi_breakin_enable();
    tbu_pmcg_configure();
    ect_top_hs_configure();

    c_uvm_info("%s", "ect top handshake: top ch7/8/14 -> AON handshake outputs configured");
    C_PASS();
CPU_TEST_END
