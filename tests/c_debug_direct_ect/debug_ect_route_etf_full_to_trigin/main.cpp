/*
 * debug_ect_route_etf_full_to_trigin/main.cpp
 *
 * Configure one AON ECT route:
 *
 *   ETF.full (CTI_AON event_in[0])
 *     -> CTI channel[0]
 *     -> ETF.trigin (CTI_AON event_out[1])
 *
 * Per project convention, CTI input index == CTM channel index.  This case
 * only enables channel 0 and leaves all other input/output mappings disabled.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define ECT_ROUTE_CTI_BASE     AON_CTI_BASE
#define ECT_ROUTE_SRC_IN       0U
#define ECT_ROUTE_CHANNEL      0U
#define ECT_ROUTE_DST_OUT      1U

#define ECT_ROUTE_CH_MASK      (1U << ECT_ROUTE_CHANNEL)
#define ECT_ROUTE_INEN_OFF     CTI_INEN(ECT_ROUTE_SRC_IN)
#define ECT_ROUTE_OUTEN_OFF    CTI_OUTEN(ECT_ROUTE_DST_OUT)

static void ect_route_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_ROUTE_CTI_BASE + offset), value);
}

static uint32_t ect_route_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_ROUTE_CTI_BASE + offset));
}

static void ect_route_clear_all_maps(void)
{
    uint32_t i;

    for (i = 0U; i < 16U; ++i) {
        ect_route_write(CTI_INEN(i), 0U);
        ect_route_write(CTI_OUTEN(i), 0U);
    }
}

static void ect_route_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t inen;
    uint32_t outen;

    /* Configure only while the CTI is disabled. */
    ctrl = ect_route_read(CTI_CONTROL);
    c_uvm_info("ect route: CONTROL before config = 0x%08x", ctrl);
    ect_route_write(CTI_CONTROL, 0U);

    /* Clear old mappings so only the requested route can fire. */
    ect_route_clear_all_maps();

    /* input[0] -> channel[0] */
    inen = ECT_ROUTE_CH_MASK;
    ect_route_write(ECT_ROUTE_INEN_OFF, inen);

    /* channel[0] -> output[1] (ETF.trigin) */
    outen = ECT_ROUTE_CH_MASK;
    ect_route_write(ECT_ROUTE_OUTEN_OFF, outen);

    /* Allow only channel 0 through the gate. */
    gate = ECT_ROUTE_CH_MASK;
    ect_route_write(CTI_GATE, gate);

    /* Enable the CTI. */
    ect_route_write(CTI_CONTROL, CTI_CONTROL_EN);

    /* Read back the exact route used by this case. */
    ctrl = ect_route_read(CTI_CONTROL);
    gate = ect_route_read(CTI_GATE);
    inen = ect_route_read(ECT_ROUTE_INEN_OFF);
    outen = ect_route_read(ECT_ROUTE_OUTEN_OFF);

    c_uvm_info("ect route: CONTROL=0x%08x GATE=0x%08x INEN0=0x%08x OUTEN1=0x%08x",
               ctrl, gate, inen, outen);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != ECT_ROUTE_CH_MASK ||
        inen != ECT_ROUTE_CH_MASK ||
        outen != ECT_ROUTE_CH_MASK) {
        c_uvm_error("%s", "ect route: CTI route readback mismatch");
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    ect_route_configure();

    c_uvm_info("%s", "ect route: ETF.full -> ch0 -> ETF.trigin configured");
    C_PASS();
CPU_TEST_END
