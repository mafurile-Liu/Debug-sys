/*
 * debug_ect_top_chin_to_evtout_pulse/main.cpp
 *
 * Program direct CTM-top-channel to AON CTI output mappings for the
 * non-handshake event outputs:
 *
 *   CTI_AON channel[i] -> CTI_AON event_out[i]
 *
 * Handshake outputs 7/8/14 are covered by the dedicated handshake case.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define ECT_TOP_PULSE_CTI_BASE  AON_CTI_BASE
#define ECT_TOP_PULSE_CH_MASK   0x3E7FU

static void ect_top_pulse_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_TOP_PULSE_CTI_BASE + offset), value);
}

static uint32_t ect_top_pulse_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_TOP_PULSE_CTI_BASE + offset));
}

static int ect_top_pulse_is_mapped(uint32_t output)
{
    return (output <= 6U) ||
           ((output >= 9U) && (output <= 13U));
}

static void ect_top_pulse_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t i;
    uint32_t outen;

    ctrl = ect_top_pulse_read(CTI_CONTROL);
    c_uvm_info("ect top pulse: CONTROL before config = 0x%08x", ctrl);
    ect_top_pulse_write(CTI_CONTROL, 0U);

    /* channel[i] -> event_out[i] for all non-handshake outputs */
    for (i = 0U; i < 15U; ++i) {
        if (ect_top_pulse_is_mapped(i)) {
            ect_top_pulse_write(CTI_OUTEN(i), (1U << i));
        }
    }

    /* Only the channels used by this pulse case pass the gate. */
    gate = ECT_TOP_PULSE_CH_MASK;
    ect_top_pulse_write(CTI_GATE, gate);

    ect_top_pulse_write(CTI_CONTROL, CTI_CONTROL_EN);

    ctrl = ect_top_pulse_read(CTI_CONTROL);
    gate = ect_top_pulse_read(CTI_GATE);

    c_uvm_info("ect top pulse: CONTROL=0x%08x GATE=0x%08x", ctrl, gate);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != ECT_TOP_PULSE_CH_MASK) {
        c_uvm_error("%s", "ect top pulse: CTI route readback mismatch");
    }

    for (i = 0U; i < 15U; ++i) {
        if (!ect_top_pulse_is_mapped(i)) {
            continue;
        }
        outen = ect_top_pulse_read(CTI_OUTEN(i));
        if (outen != (1U << i)) {
            c_uvm_error("ect top pulse: OUTEN%0d mismatch = 0x%08x", i, outen);
        }
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    ect_top_pulse_configure();

    c_uvm_info("%s", "ect top pulse: top ch0..6/9..13 -> AON event_out configured");
    C_PASS();
CPU_TEST_END
