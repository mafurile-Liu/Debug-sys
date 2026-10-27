/*
 * c_config_m52_trace_dbm0_CORES_m52/main.cpp
 *
 * ACPU/M52 co-executed DBM0 trace smoke case.
 *
 * ACPU configures the AON trace path and DBM0.  M52 waits for ACPU, then
 * performs a larger read/write traffic burst on its CPU bus.  DBM0 converts
 * that bus activity to ATB trace and sends it through AON funnel slave
 * port 5 into the AON trace tree.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug_small.h"
#include "coresight_trace_regs.h"

/*
 * DBM0 register map supplied by design:
 *   cfg_en @ 0x000: bit0 rd, bit1 wr
 *   trace   @ 0x100: bit0 atb_en, bit1 atb_mode
 */
#define AON_DBM0_BASE             0x02183000U
#define AON_DBM0_CFG_EN_REG       (AON_DBM0_BASE + 0x000U)
#define AON_DBM0_TRACE_REG        (AON_DBM0_BASE + 0x100U)

#define AON_DBM0_CFG_EN_RD        (1U << 0)
#define AON_DBM0_CFG_EN_WR        (1U << 1)
#define AON_DBM0_CFG_EN_MASK      (AON_DBM0_CFG_EN_RD | \
                                   AON_DBM0_CFG_EN_WR)
#define AON_DBM0_TRACE_ATB_EN     (1U << 0)
#define AON_DBM0_TRACE_ATB_MODE   (1U << 1)
#define AON_DBM0_TRACE_MASK       (AON_DBM0_TRACE_ATB_EN | \
                                   AON_DBM0_TRACE_ATB_MODE)

/* DBM0 is connected to AON funnel slave port 5. */
#define AON_DBM0_FUNNEL_SLAVE_PORT 5U
#define AON_DBM0_FUNNEL_MASK       (1U << AON_DBM0_FUNNEL_SLAVE_PORT)

#define AON_TRACE_BUF_ADDR        AON_SRAM_BASE_ADDR
#define AON_TRACE_BUF_SIZE        0x00010000U
#define AON_SRAM_CHECK_BYTES      0x00000100U

/*
 * Put CPU/M52 handshake and M52 scratch traffic outside the ETR buffer so
 * they do not corrupt the checked trace-data window.
 */
#define AON_M52_START_FLAG_ADDR   (AON_TRACE_BUF_ADDR + AON_TRACE_BUF_SIZE)
#define AON_M52_DONE_FLAG_ADDR    (AON_TRACE_BUF_ADDR + AON_TRACE_BUF_SIZE + 4U)
#define AON_M52_START_FLAG        0xC0DE0001U
#define AON_M52_DONE_FLAG         0xC0DE0002U
#define AON_M52_SCRATCH_ADDR      (AON_TRACE_BUF_ADDR + 0x00020000U)
#define AON_M52_SCRATCH_WORDS     128U
#define AON_M52_SCRATCH_PATTERN   0x444D4230U

static void m52_check_reg(const char *name,
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

static void aon_sram_trace_data_check(void)
{
    uint32_t off;
    uint32_t got;

    for (off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        got = R32((uintptr_t)(AON_TRACE_BUF_ADDR + off));
        if (got != 0U) {
            c_uvm_info("AON SRAM DBM0 check: first nonzero @0x%08x=0x%08x",
                       AON_TRACE_BUF_ADDR + off, got);
            return;
        }
    }

    c_uvm_error("%s", "AON SRAM DBM0 check: no nonzero data found");
}

COP_TEST_START
    /*
     * Keep the M52 side minimal: wait until ACPU has enabled DBM0, issue a
     * larger read/write burst, then report completion.
     */
    while (R32((uintptr_t)AON_M52_START_FLAG_ADDR) != AON_M52_START_FLAG) {
    }

    {
        uint32_t word;

        for (word = 0U; word < AON_M52_SCRATCH_WORDS; ++word) {
            W32((uintptr_t)(AON_M52_SCRATCH_ADDR + (word * 4U)),
                AON_M52_SCRATCH_PATTERN + word);
        }

        for (word = 0U; word < AON_M52_SCRATCH_WORDS; ++word) {
            (void)R32((uintptr_t)(AON_M52_SCRATCH_ADDR + (word * 4U)));
        }
    }

    W32((uintptr_t)AON_M52_DONE_FLAG_ADDR, AON_M52_DONE_FLAG);
    COP_C_PASS();
COP_TEST_END

static void dbm0_config(void)
{
    uint32_t cfg_en = AON_DBM0_CFG_EN_RD | AON_DBM0_CFG_EN_WR;
    uint32_t trace = AON_DBM0_TRACE_ATB_EN | AON_DBM0_TRACE_ATB_MODE;

    W32(AON_DBM0_CFG_EN_REG, cfg_en);
    W32(AON_DBM0_TRACE_REG, trace);

    m52_check_reg("DBM0_CFG_EN", R32(AON_DBM0_CFG_EN_REG),
                  cfg_en, AON_DBM0_CFG_EN_MASK);
    m52_check_reg("DBM0_TRACE", R32(AON_DBM0_TRACE_REG),
                  trace, AON_DBM0_TRACE_MASK);
}

CPU_TEST_START
    OPEN_DEBUG_CRG_SMALL();

    // --------------- clks cfg finish ---------------- //

    /*
     * Clear the checked SRAM window and handshake flags before configuring
     * the trace path. This prevents stale data or a stale start flag from
     * letting M52 run before DBM0 is enabled.
     */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)(AON_TRACE_BUF_ADDR + off), 0U);
    }
    W32((uintptr_t)AON_M52_START_FLAG_ADDR, 0U);
    W32((uintptr_t)AON_M52_DONE_FLAG_ADDR, 0U);

    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   AON_DBM0_FUNNEL_MASK,
                   AON_TRACE_BUF_ADDR,
                   AON_TRACE_BUF_SIZE,
                   CATU_SLADDR_DEFAULT);

    dbm0_config();

    /*
     * Let the minimal M52 COP code run while DBM0 is active, then flush the
     * DBM0-only trace path.
     */
    W32((uintptr_t)AON_M52_START_FLAG_ADDR, AON_M52_START_FLAG);
    {
        uint32_t done = 0U;

        for (uint32_t timeout = 0U; timeout < 100000U; ++timeout) {
            done = R32((uintptr_t)AON_M52_DONE_FLAG_ADDR);
            if (done == AON_M52_DONE_FLAG) {
                break;
            }
        }

        if (done != AON_M52_DONE_FLAG) {
            c_uvm_error("%s", "M52 DBM0 activity did not complete");
        }
    }

    aon_trace_flush();
    delay_us(1);

    /*
     * ITM/ETM are not enabled in this case, so nonzero trace data in the
     * checked SRAM window must have come from DBM0.
     */
    aon_sram_trace_data_check();

    c_uvm_info("%s", "DBM0 trace enabled and M52 bus traffic captured");
    C_PASS();
CPU_TEST_END
