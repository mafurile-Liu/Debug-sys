/*
 * debug_ect_evtin6_7_hs_to_ch14_15/main.cpp
 *
 * Dedicated AON ECT handshake routes:
 *
 *   CTI_AON event_in[6] / CrossTriggerOut -> channel[14]
 *   CTI_AON event_in[7] / BreakOut        -> channel[15]
 *
 * Both source triggers are handshake type.  The UVM test uses handshake
 * sequences and must observe the corresponding ack; an ack timeout is an
 * error.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define ECT_HS_CTI_BASE     AON_CTI_BASE
#define ECT_HS_SRC0         6U
#define ECT_HS_CH0          14U
#define ECT_HS_SRC1         7U
#define ECT_HS_CH1          15U
#define ECT_HS_CH_MASK      ((1U << ECT_HS_CH0) | (1U << ECT_HS_CH1))

static void ect_hs_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_HS_CTI_BASE + offset), value);
}

static uint32_t ect_hs_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_HS_CTI_BASE + offset));
}

static void ect_hs_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t inen0;
    uint32_t inen1;

    ctrl = ect_hs_read(CTI_CONTROL);
    c_uvm_info("ect hs: CONTROL before config = 0x%08x", ctrl);
    ect_hs_write(CTI_CONTROL, 0U);

    /* event_in[6] -> channel[14] */
    inen0 = (1U << ECT_HS_CH0);
    ect_hs_write(CTI_INEN(ECT_HS_SRC0), inen0);

    /* event_in[7] -> channel[15] */
    inen1 = (1U << ECT_HS_CH1);
    ect_hs_write(CTI_INEN(ECT_HS_SRC1), inen1);

    /* Only the dedicated handshake channels pass the gate. */
    gate = ECT_HS_CH_MASK;
    ect_hs_write(CTI_GATE, gate);

    ect_hs_write(CTI_CONTROL, CTI_CONTROL_EN);

    ctrl  = ect_hs_read(CTI_CONTROL);
    gate  = ect_hs_read(CTI_GATE);
    inen0 = ect_hs_read(CTI_INEN(ECT_HS_SRC0));
    inen1 = ect_hs_read(CTI_INEN(ECT_HS_SRC1));

    c_uvm_info("ect hs: CONTROL=0x%08x GATE=0x%08x INEN6=0x%08x INEN7=0x%08x",
               ctrl, gate, inen0, inen1);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != ECT_HS_CH_MASK ||
        inen0 != (1U << ECT_HS_CH0) ||
        inen1 != (1U << ECT_HS_CH1)) {
        c_uvm_error("%s", "ect hs: handshake route readback mismatch");
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    ect_hs_configure();

    c_uvm_info("%s", "ect hs: event_in6/7 -> channel14/15 configured");
    C_PASS();
CPU_TEST_END
