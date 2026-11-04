/*
 * debug_ect_m52_evtin_to_evtout/main.cpp
 *
 * Configure direct M52 CTI routes:
 *
 *   event_in[0] -> channel[0] -> event_out[0]
 *   event_in[2] -> channel[1] -> event_out[1]
 *   event_in[3] -> channel[2] -> event_out[2]
 *   event_in[4] -> channel[3] -> event_out[3]
 *
 * event_in[1] is not connected in the current ECT mapping and event_in[5]
 * is intentionally left unused so every route remains one-to-one.
 * M52 CTI is programmed through the M52 AHB-AP debug window.
 * CTI base is from M52 TRM Table 8-4 (EPPB memory region).
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug_small.h"

#define M52_CTI_BASE        0xE0042000U
#define M52_CTI_CONTROL     (M52_CTI_BASE + 0x000U)
#define M52_CTI_INEN(n)     (M52_CTI_BASE + 0x020U + ((n) * 4U))
#define M52_CTI_OUTEN(n)    (M52_CTI_BASE + 0x0A0U + ((n) * 4U))
#define M52_CTI_GATE        (M52_CTI_BASE + 0x140U)
#define M52_CTI_CONTROL_EN  (1U << 0)

static const uint32_t m52_evt_in_idx[4] = {0U, 2U, 3U, 4U};

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
    m52_ahbap_write(M52_CTI_CONTROL, 0U);
    m52_cti_check_reg("M52_CTI_CONTROL(disabled)",
                      m52_ahbap_read(M52_CTI_CONTROL),
                      0U, M52_CTI_CONTROL_EN);

    /* event_in -> channel, one-to-one for the four CTM channels. */
    for (i = 0U; i < 4U; ++i) {
        m52_ahbap_write(M52_CTI_INEN(m52_evt_in_idx[i]), (1U << i));
    }

    /* channel[i] -> event_out[i]. */
    for (i = 0U; i < 4U; ++i) {
        m52_ahbap_write(M52_CTI_OUTEN(i), (1U << i));
    }

    /* Only the four configured channels pass the CTI gate. */
    m52_ahbap_write(M52_CTI_GATE, 0x0000000FU);
    m52_ahbap_write(M52_CTI_CONTROL, M52_CTI_CONTROL_EN);

    m52_cti_check_reg("M52_CTI_CONTROL(enabled)",
                      m52_ahbap_read(M52_CTI_CONTROL),
                      M52_CTI_CONTROL_EN, M52_CTI_CONTROL_EN);
    m52_cti_check_reg("M52_CTI_GATE",
                      m52_ahbap_read(M52_CTI_GATE),
                      0x0000000FU, 0x0000000FU);

    for (i = 0U; i < 4U; ++i) {
        uint32_t inen = m52_ahbap_read(M52_CTI_INEN(m52_evt_in_idx[i]));
        uint32_t outen = m52_ahbap_read(M52_CTI_OUTEN(i));

        c_uvm_info("M52_CTI route%0d: INEN(evt_in%0d)=0x%08x OUTEN%0d=0x%08x",
                   i, m52_evt_in_idx[i], inen, i, outen);

        if (inen != (1U << i)) {
            c_uvm_error("M52_CTI INEN readback mismatch: idx=%0d got=0x%08x want=0x%08x",
                        m52_evt_in_idx[i], inen, (1U << i));
        }
        if (outen != (1U << i)) {
            c_uvm_error("M52_CTI OUTEN readback mismatch: idx=%0d got=0x%08x want=0x%08x",
                        i, outen, (1U << i));
        }
    }
}

COP_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    /* Configure the M52 PPB access window before any M52 register access. */
    m52_ahbap_config();
    m52_cti_check_reg("M52_AHBAP_IDR",
                      m52_ahbap_idr(), 0x54770008U, 0xFFFFFF00U);

    m52_cti_configure();

    c_uvm_info("%s", "M52 CTI event_in -> channel -> event_out configured");
    C_PASS();
COP_TEST_END
