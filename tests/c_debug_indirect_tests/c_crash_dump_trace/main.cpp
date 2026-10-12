/*
 * c_crash_dump_trace/main.cpp
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
 * IMPORTANT:
 *   The crash_dump APB register offsets/bits below are RESERVED placeholders.
 *   They must be replaced with the design-provided register map before this
 *   case is used as a pass/fail regression on RTL.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

/* ------------------------------------------------------------------ */
/* RESERVED crash_dump register map: TODO(design) replace these.      */
/* Base is confirmed as 0x4A20_7000; offsets/bits are not confirmed.   */
/* ------------------------------------------------------------------ */
#define CD_CTRL                   0x000U
#define CD_STATUS                 0x004U
#define CD_ATID                   0x008U
#define CD_TAR0                   0x010U
#define CD_SIZE0                  0x014U

#define CD_CTRL_EN                (1U << 0)
#define CD_CTRL_SW_TRG            (1U << 1)
#define CD_STATUS_DONE            (1U << 0)
#define CD_STATUS_ERR             (1U << 1)

/* M52 debug aperture from dbg_address_mapping.xlsx, m9 m52_for_crash_dump. */
#define M52_DEBUG_WINDOW_BASE     M52_CRASH_DUMP_BASE
#define M52_DEBUG_WORDS           8U

/* AON SRAM is used by the ETR as the trace buffer. */
#define AON_TRACE_BUF_SIZE        0x00010000U
#define AON_SRAM_CHECK_BYTES      0x00000400U

static void m52_debug_write_pattern(void)
{
    uint32_t i;

    for (i = 0U; i < M52_DEBUG_WORDS; ++i) {
        uint32_t addr = (uintptr_t)M52_DEBUG_WINDOW_BASE + (i * 4U);
        uint32_t data = 0xC0DE1000U + i;

        W32(addr, data);
        c_uvm_info("m52 debug wr[0x%08x]=0x%08x", addr, data);
    }
}

static void crash_dump_config_and_trigger(void)
{
    uint32_t status;
    uint32_t timeout;

    /*
     * RESERVED: program only one source range for the smoke case.
     * CD_SIZE0 is assumed to be a byte count; if the design uses a word
     * count or an encoded range, update this write when the map is known.
     */
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_ATID, 0x00000001U);
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_TAR0, M52_DEBUG_WINDOW_BASE);
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SIZE0,
        M52_DEBUG_WORDS * 4U);

    /* TODO(design): EN/SW_TRG may be separate registers in the real map. */
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_CTRL,
        CD_CTRL_EN | CD_CTRL_SW_TRG);

    status = R32((uintptr_t)AON_CRASH_DUMP_BASE + CD_STATUS);
    for (timeout = 100000U; timeout != 0U; --timeout) {
        if ((status & CD_STATUS_DONE) != 0U) {
            break;
        }
        status = R32((uintptr_t)AON_CRASH_DUMP_BASE + CD_STATUS);
    }

    c_uvm_info("crash dump status=0x%08x timeout_left=%0d", status, timeout);
    if (timeout == 0U) {
        c_uvm_error("%s", "crash dump did not set DONE");
    }
    if ((status & CD_STATUS_ERR) != 0U) {
        c_uvm_error("%s", "crash dump reported ERROR");
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

        m52_debug_write_pattern();

        /* RESERVED crash_dump programming and trigger. */
        crash_dump_config_and_trigger();

        /*
         * The crash_dump ATB payload is {data, addr}; therefore the 32-bit
         * data word is expected to appear in the ETR trace buffer. Search
         * for it, independent of the exact 64-bit packet layout/endian view.
         */
        for (uint32_t i = 0U; i < M52_DEBUG_WORDS; ++i) {
            uint32_t want = 0xC0DE1000U + i;
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
