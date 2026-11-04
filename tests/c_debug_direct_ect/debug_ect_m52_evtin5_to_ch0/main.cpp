/*
 * debug_ect_m52_evtin5_to_ch0/main.cpp
 *
 * Program the remaining connected M52 CTI input trigger:

  event_in[5] -> channel[0]

This is a separate route group because M52 CTI has only four CTM channels.
No output mapping is programmed in this event-in-only case.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug_small.h"

/* M52 CTI base: M52 TRM Table 8-4, EPPB region. */
#define M52_CTI_BASE        0xE0042000U
#define M52_CTI_CONTROL     (M52_CTI_BASE + 0x000U)
#define M52_CTI_INEN(n)     (M52_CTI_BASE + 0x020U + ((n) * 4U))
#define M52_CTI_OUTEN(n)    (M52_CTI_BASE + 0x0A0U + ((n) * 4U))
#define M52_CTI_GATE        (M52_CTI_BASE + 0x140U)
#define M52_CTI_CONTROL_EN  (1U << 0)

static void m52_cti_write(uint32_t offset, uint32_t value)
{
    m52_ahbap_write(offset, value);
}

static uint32_t m52_cti_read(uint32_t offset)
{
    return m52_ahbap_read(offset);
}

static void m52_cti_check_reg(const char *name,
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

static void m52_cti_configure(void)
{
    /* Configure only while the CTI is disabled. */
    m52_cti_write(M52_CTI_CONTROL, 0U);
    m52_cti_check_reg("M52_CTI_CONTROL(disabled)",
                      m52_cti_read(M52_CTI_CONTROL),
                      0U, M52_CTI_CONTROL_EN);

    /* The fifth connected input trigger uses channel0 in this group. */
    m52_cti_write(M52_CTI_INEN(5U), (1U << 0U));
    m52_cti_write(M52_CTI_GATE, (1U << 0U));
    m52_cti_write(M52_CTI_CONTROL, M52_CTI_CONTROL_EN);

    m52_cti_check_reg("M52_CTI_CONTROL(enabled)",
                      m52_cti_read(M52_CTI_CONTROL),
                      M52_CTI_CONTROL_EN, M52_CTI_CONTROL_EN);
    m52_cti_check_reg("M52_CTI_GATE",
                      m52_cti_read(M52_CTI_GATE),
                      (1U << 0U), (1U << 0U));
    m52_cti_check_reg("M52_CTI_INEN5",
                      m52_cti_read(M52_CTI_INEN(5U)),
                      (1U << 0U), (1U << 0U));
}

CPU_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    m52_ahbap_config();
    m52_cti_check_reg("M52_AHBAP_IDR",
                      m52_ahbap_idr(), 0x54770008U, 0xFFFFFF00U);

    m52_cti_configure();

    c_uvm_info("%s", "M52 CTI event_in5 -> channel0 configured");
    C_PASS();
COP_TEST_END