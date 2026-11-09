/*
 * debug_ect_m52_evtin0_1_2_3_to_ch/main.cpp
 *
 * Program M52 CTI input-to-channel routes (corrected event mapping:
 * dwt_cmpmatch_i[2:0] drives event_in[3:1]):

  event_in[0] -> channel[0]
  event_in[1] -> channel[1]
  event_in[2] -> channel[2]
  event_in[3] -> channel[3]
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

static const uint32_t m52_evt_in_idx[4] = {0U, 1U, 2U, 3U};

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

    /* One connected input trigger maps to one CTM channel. */
    for (i = 0U; i < 4U; ++i) {
        m52_cti_write(M52_CTI_INEN(m52_evt_in_idx[i]), (1U << i));
    }

    /* Only the configured channels pass the gate.  No output map here. */
    m52_cti_write(M52_CTI_GATE, 0x0000000FU);
    m52_cti_write(M52_CTI_CONTROL, M52_CTI_CONTROL_EN);

    m52_cti_check_reg("M52_CTI_CONTROL(enabled)",
                      m52_cti_read(M52_CTI_CONTROL),
                      M52_CTI_CONTROL_EN, M52_CTI_CONTROL_EN);
    m52_cti_check_reg("M52_CTI_GATE",
                      m52_cti_read(M52_CTI_GATE),
                      0x0000000FU, 0x0000000FU);

    for (i = 0U; i < 4U; ++i) {
        uint32_t inen = m52_cti_read(M52_CTI_INEN(m52_evt_in_idx[i]));
        c_uvm_info("M52_CTI route%0d: INEN(evt_in%0d)=0x%08x",
                   i, m52_evt_in_idx[i], inen);
        if (inen != (1U << i)) {
            c_uvm_error("M52_CTI INEN readback mismatch: idx=%0d got=0x%08x want=0x%08x",
                        m52_evt_in_idx[i], inen, (1U << i));
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

    c_uvm_info("%s", "M52 CTI non-handshake event_in0/1/2/3 -> channel0..3 configured");
    C_PASS();
COP_TEST_END
