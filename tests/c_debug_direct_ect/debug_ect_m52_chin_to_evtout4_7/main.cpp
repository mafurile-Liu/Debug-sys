/*
 * debug_ect_m52_chin_to_evtout4_7/main.cpp
 *
 * Program M52 CTI channel-to-output routes for output group 4..7:

  channel[0] -> event_out[4]
  channel[1] -> event_out[5]
  channel[2] -> event_out[6]
  channel[3] -> event_out[7]
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
    uint32_t i;

    /* Configure only while the CTI is disabled. */
    m52_cti_write(M52_CTI_CONTROL, 0U);
    m52_cti_check_reg("M52_CTI_CONTROL(disabled)",
                      m52_cti_read(M52_CTI_CONTROL),
                      0U, M52_CTI_CONTROL_EN);

    /* channel[i] -> event_out[i + 4] for output group 4..7. */
    for (i = 0U; i < 4U; ++i) {
        m52_cti_write(M52_CTI_OUTEN(i + 4U), (1U << i));
    }

    /* Only the four source channels pass the gate. */
    m52_cti_write(M52_CTI_GATE, 0x0000000FU);
    m52_cti_write(M52_CTI_CONTROL, M52_CTI_CONTROL_EN);

    m52_cti_check_reg("M52_CTI_CONTROL(enabled)",
                      m52_cti_read(M52_CTI_CONTROL),
                      M52_CTI_CONTROL_EN, M52_CTI_CONTROL_EN);
    m52_cti_check_reg("M52_CTI_GATE",
                      m52_cti_read(M52_CTI_GATE),
                      0x0000000FU, 0x0000000FU);

    for (i = 0U; i < 4U; ++i) {
        uint32_t outen = m52_cti_read(M52_CTI_OUTEN(i + 4U));
        c_uvm_info("M52_CTI route%0d: OUTEN%0d=0x%08x", i, i + 4U, outen);
        if (outen != (1U << i)) {
            c_uvm_error("M52_CTI OUTEN readback mismatch: idx=%0d got=0x%08x want=0x%08x",
                        i + 4U, outen, (1U << i));
        }
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    m52_ahbap_config();
    m52_cti_check_reg("M52_AHBAP_IDR",
                      m52_ahbap_idr(), 0x54770008U, 0xFFFFFF00U);

    m52_cti_configure();

    c_uvm_info("%s", "M52 CTI channel0..3 -> event_out4..7 configured");
    C_PASS();
COP_TEST_END