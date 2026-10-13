/*
 * c_trace_crash_dump/main.cpp
 *
 * Crash-dump -> AON trace -> AON SRAM smoke test.
 *
 * The intended flow is:
 *   1. configure the AON trace path
 *   2. write known data to the M52 debug aperture
 *   3. program one crash_dump source range at the same aperture
 *   4. trigger crash_dump and wait for dump done
 *   5. search the AON SRAM trace buffer for the expected dump data
 *
 * Crash_dump register offsets/bits are from the design-provided register map:
 *   CTRL 0x000, SW_TRG 0x004, STATUS 0x008, ATB_ID 0x00C,
 *   TAR_ADDR0-7 0x010-0x02C, SIZE0-7 0x030-0x04C.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

/* Crash_dump register map supplied by design. */
#define CD_CTRL_REG               0x000U
#define CD_SW_TRG_REG             0x004U
#define CD_STATUS_REG             0x008U
#define CD_ATB_ID_REG             0x00CU

#define CD_TAR_ADDR_REG(x)        (0x010U + ((x) * 4U))
#define CD_SIZE_REG(x)            (0x030U + ((x) * 4U))

#define CD_CTRL_EN                (1U << 0)
#define CD_SW_TRG_PULSE           (1U << 0)
#define CD_STATUS_DONE            (1U << 0)
#define CD_STATUS_APB_RD_ERROR    (1U << 4)

/*
 * The M52 debug block has two views:
 *   - The AHB-AP target address uses the M52 internal PPB view.
 *   - crash_dump's APB master goes through APBIC m9 at 0x4A30_0000, which
 *     remaps M52 PPB 0xE000_0000.
 *
 * Use DWT comparator registers as the crash-dump payload. They are RW in the
 * M52 TRM and readable back by crash_dump. ITM_STIM0-31 at 0xE000_0000 must
 * not be used: writes there are stimulus transfers, not stored data, and ITM
 * requires DEMCR.TRCENA to be enabled first (M52 TRM 18.2/19.5).
 */
#define M52_DEBUG_APBIC_BASE      M52_CRASH_DUMP_BASE
#define M52_DEBUG_WORDS           2U
#define M52_DEBUG_BYTES           (M52_DEBUG_WORDS * 4U)

/* AON SRAM is used by the ETR as the trace buffer. */
#define AON_TRACE_BUF_SIZE        0x00010000U
#define AON_SRAM_CHECK_BYTES      0x00000400U

static void m52_debug_write_pattern(void)
{
    uint32_t i;

    /* DWT/ITM debugger accesses are gated by DEMCR.TRCENA (M52 TRM 19.1). */
    m52_ahbap_write(M52_DEMCR, M52_DEMCR_TRCENA);

    for (i = 0U; i < M52_DEBUG_WORDS; ++i) {
        uint32_t addr = M52_DWT_COMP_REG(i);
        uint32_t data = 0xC0DE2000U + i;
        uint32_t readback;

        m52_ahbap_write(addr, data);
        readback = m52_ahbap_read(addr);
        if (readback != data) {
            c_uvm_error("m52 dwt comp%0d wr=0x%08x rd=0x%08x",
                        i, data, readback);
        }
        c_uvm_info("m52 debug wr[0x%08x]=0x%08x", addr, data);
    }
}

static void crash_dump_config_and_trigger(void)
{
    uint32_t status;
    uint32_t timeout;
    uint32_t range;

    /*
     * Program one 4-byte range per DWT comparator. The APB read offset
     * increments by 4 and is compared against size, so SIZE is a byte count.
     */
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_ATB_ID_REG, 0x00000001U);

    /* Ranges 1-7 are unused; keep them zero. */
    for (range = 0U; range < M52_DEBUG_WORDS; ++range) {
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_TAR_ADDR_REG(range),
            M52_DEBUG_APBIC_BASE + M52_DWT_COMP_REG(range) - 0xE0000000U);
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SIZE_REG(range), 4U);
    }

    /* Ranges beyond the used DWT comparators are unused; keep them zero. */
    for (range = M52_DEBUG_WORDS; range < 8U; ++range) {
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_TAR_ADDR_REG(range), 0U);
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SIZE_REG(range), 0U);
    }

    /* Enable first, then issue a one-cycle software-trigger pulse. */
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_CTRL_REG, CD_CTRL_EN);
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SW_TRG_REG, CD_SW_TRG_PULSE);

    for (timeout = 100000U; timeout != 0U; --timeout) {
        status = R32((uintptr_t)AON_CRASH_DUMP_BASE + CD_STATUS_REG);
        if ((status & CD_STATUS_DONE) != 0U) {
            break;
        }
    }

    c_uvm_info("crash dump status=0x%08x timeout_left=%0d", status, timeout);
    if (timeout == 0U) {
        c_uvm_error("%s", "crash dump did not set DONE");
    }
    if ((status & CD_STATUS_APB_RD_ERROR) != 0U) {
        c_uvm_error("%s", "crash dump reported APB read error");
    }

    if (timeout != 0U) {
        /*
         * DONE means all ATB data has been sent; allow simulation time for
         * the trace fabric/ETR write path to reach AON SRAM before reading.
         */
        delay_us(1);
    }
}

static int aon_sram_find_word(uint32_t value, uint32_t *found_off)
{
    uint32_t off;

    for (off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        if (R32((uintptr_t)AON_SRAM_BASE_ADDR + off) == value) {
            *found_off = off;
            return 1;
        }
    }
    return 0;
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /*
     * Configure AON trace before triggering crash_dump.
     * Path: crash_dump(ATB) -> AON_FUNNEL port0 -> ETF -> ETR -> AON SRAM.
     * CATU is left in pass-through because the ETR buffer is linear.
     */
    aon_trace_init(TRACE_MODE_ETF_CATU_BYPASS,
                   0x01U,
                   AON_SRAM_BASE_ADDR,
                   AON_TRACE_BUF_SIZE,
                   CATU_SLADDR_DEFAULT);

    /* Make comparison easier by clearing the first portion of the buffer. */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)AON_SRAM_BASE_ADDR + off, 0U);
    }

    /* Write known data into the M52 debug aperture. */
    {
        uint32_t missing = 0U;

        m52_ahbap_config();
        m52_debug_write_pattern();

        /* Program and trigger crash_dump through the design register map. */
        crash_dump_config_and_trigger();

        /*
         * The crash_dump ATB payload is {data, addr}; therefore the 32-bit
         * data word is expected to appear in the ETR trace buffer. Search
         * for it, independent of the exact 64-bit packet layout/endian view.
         */
        for (uint32_t i = 0U; i < M52_DEBUG_WORDS; ++i) {
            uint32_t want = 0xC0DE2000U + i;
            uint32_t found_off;

            if (aon_sram_find_word(want, &found_off) != 0U) {
                c_uvm_info("dump data 0x%08x found at AON SRAM 0x%08x",
                           want, AON_SRAM_BASE_ADDR + found_off);
            } else {
                ++missing;
                c_uvm_error("dump data 0x%08x not found in AON SRAM", want);
            }
        }

        if (missing == 0U) {
            c_uvm_info("%s", "crash dump trace data check passed");
        }
    }

    C_PASS();
CPU_TEST_END
