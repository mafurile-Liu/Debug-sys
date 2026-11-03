/*
 * debug_ect_evt_in0_to9_direct_map/main.cpp
 *
 * Program direct event-in to CTM-channel mappings for AON CTI inputs 0..9:
 *
 *   CTI_AON event_in[i] -> channel[i]
 *   channel[i]          -> CTI_AON event_out[1] / ETF.trigin
 *
 * This lets the UVM case inject event_in[0..9] one at a time and check that
 * only the directly mapped channel and output fire.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define ECT_DIRECT_CTI_BASE     AON_CTI_BASE
#define ECT_DIRECT_MIN_EVT      0U
#define ECT_DIRECT_MAX_EVT      9U
#define ECT_DIRECT_OUT          1U
#define ECT_DIRECT_CH_MASK      0x3FFU

static void ect_direct_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_DIRECT_CTI_BASE + offset), value);
}

static uint32_t ect_direct_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_DIRECT_CTI_BASE + offset));
}


static void ect_direct_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t i;
    uint32_t inen;
    uint32_t outen;

    ctrl = ect_direct_read(CTI_CONTROL);
    c_uvm_info("ect direct map: CONTROL before config = 0x%08x", ctrl);
    ect_direct_write(CTI_CONTROL, 0U);

    /* One input event maps directly to the same channel index. */
    for (i = ECT_DIRECT_MIN_EVT; i <= ECT_DIRECT_MAX_EVT; ++i) {
        ect_direct_write(CTI_INEN(i), (1U << i));
    }

    /* All directly mapped channels drive ETF.trigin. */
    outen = ECT_DIRECT_CH_MASK;
    ect_direct_write(CTI_OUTEN(ECT_DIRECT_OUT), outen);

    /* Only channels 0..9 are allowed through the gate. */
    gate = ECT_DIRECT_CH_MASK;
    ect_direct_write(CTI_GATE, gate);

    ect_direct_write(CTI_CONTROL, CTI_CONTROL_EN);

    ctrl = ect_direct_read(CTI_CONTROL);
    gate = ect_direct_read(CTI_GATE);
    outen = ect_direct_read(CTI_OUTEN(ECT_DIRECT_OUT));

    c_uvm_info("ect direct map: CONTROL=0x%08x GATE=0x%08x OUTEN1=0x%08x",
               ctrl, gate, outen);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != ECT_DIRECT_CH_MASK ||
        outen != ECT_DIRECT_CH_MASK) {
        c_uvm_error("%s", "ect direct map: CTI direct route readback mismatch");
    }

    for (i = ECT_DIRECT_MIN_EVT; i <= ECT_DIRECT_MAX_EVT; ++i) {
        inen = ect_direct_read(CTI_INEN(i));
        if (inen != (1U << i)) {
            c_uvm_error("ect direct map: INEN%0d mismatch = 0x%08x", i, inen);
        }
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    ect_direct_configure();

    c_uvm_info("%s", "ect direct map: evt_in0..9 -> ch0..9 -> ETF.trigin configured");
    C_PASS();
CPU_TEST_END
