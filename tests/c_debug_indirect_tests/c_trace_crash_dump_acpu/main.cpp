/*
 * c_trace_crash_dump_acpu/main.cpp
 *
 * Crash-dump -> AON trace -> AON SRAM smoke test for the six ACPU
 * (Cortex-A720) cluster debug apertures.
 *
 * The flow is the same as c_trace_crash_dump, except that:
 *   - all six cluster ranges are programmed into crash_dump
 *   - no data is written to the A720 debug ROM tables. The CPU first reads
 *     the live ROM-table contents, then crash_dump reads the same addresses
 *     and the case verifies both {data, addr} halves in AON SRAM.
 *
 * Cluster debugblock_romtable windows come from dbg_address_mapping.xlsx:
 *   clst0 0x4B00_0000, clst1 0x4B28_0000, clst2 0x4B50_0000,
 *   clst3 0x4B78_0000, clst4 0x4BA0_0000, clst5 0x4BC8_0000.
 * Each mapped region is 2.5MB (0x280000). This smoke test deliberately dumps
 * only the first 16 bytes of each window to keep the trace payload small and
 * avoid writing CoreSight ROM-table space.
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

/* Six ACPU cluster debug apertures in the external/system view. */
#define ACPU_CLST0_DEBUG_BASE     0x4B000000U
#define ACPU_CLST1_DEBUG_BASE     0x4B280000U
#define ACPU_CLST2_DEBUG_BASE     0x4B500000U
#define ACPU_CLST3_DEBUG_BASE     0x4B780000U
#define ACPU_CLST4_DEBUG_BASE     0x4BA00000U
#define ACPU_CLST5_DEBUG_BASE     0x4BC80000U

#define ACPU_CLUSTER_COUNT        6U
#define ACPU_CLUSTER_DUMP_BYTES   0x00000010U
#define ACPU_CLUSTER_DUMP_WORDS   (ACPU_CLUSTER_DUMP_BYTES / 4U)

/* AON SRAM is used by the ETR as the trace buffer. 0x100 is enough for the
 * 6 x 4 x {data, addr} dump payload plus ATB sync and ETR alignment. */
#define AON_TRACE_BUF_SIZE        0x00010000U
#define AON_SRAM_CHECK_BYTES      0x00000100U

static const uint32_t acpu_cluster_bases[ACPU_CLUSTER_COUNT] = {
    ACPU_CLST0_DEBUG_BASE,
    ACPU_CLST1_DEBUG_BASE,
    ACPU_CLST2_DEBUG_BASE,
    ACPU_CLST3_DEBUG_BASE,
    ACPU_CLST4_DEBUG_BASE,
    ACPU_CLST5_DEBUG_BASE
};

static uint32_t acpu_expected_data[ACPU_CLUSTER_COUNT][ACPU_CLUSTER_DUMP_WORDS];

static void acpu_debug_capture_pattern(void)
{
    uint32_t cluster;

    for (cluster = 0U; cluster < ACPU_CLUSTER_COUNT; ++cluster) {
        uint32_t word;

        for (word = 0U; word < ACPU_CLUSTER_DUMP_WORDS; ++word) {
            uint32_t addr = acpu_cluster_bases[cluster] + (word * 4U);
            uint32_t data = R32((uintptr_t)addr);

            acpu_expected_data[cluster][word] = data;
            c_uvm_info("acpu%0d debug rd[0x%08x]=0x%08x",
                       cluster, addr, data);
        }
    }
}

static void crash_dump_config_and_trigger(void)
{
    uint32_t status;
    uint32_t timeout;
    uint32_t range;

    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_ATB_ID_REG, 0x00000001U);

    /*
     * Program the six cluster source ranges. The APB read offset increments
     * by 4 and is compared against size, so SIZE is a byte count.
     */
    for (range = 0U; range < ACPU_CLUSTER_COUNT; ++range) {
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_TAR_ADDR_REG(range),
            acpu_cluster_bases[range]);
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SIZE_REG(range),
            ACPU_CLUSTER_DUMP_BYTES);
    }

    /* Ranges 6-7 are unused; keep them zero. */
    for (range = ACPU_CLUSTER_COUNT; range < 8U; ++range) {
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_TAR_ADDR_REG(range), 0U);
        W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SIZE_REG(range), 0U);
    }

    /* Enable first, then issue a one-cycle software-trigger pulse. */
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_CTRL_REG, CD_CTRL_EN);
    W32((uintptr_t)AON_CRASH_DUMP_BASE + CD_SW_TRG_REG, CD_SW_TRG_PULSE);

    for (timeout = 1000U; timeout != 0U; --timeout) {
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
        volatile uint32_t spin;

        for (spin = 0U; spin < 64U; ++spin) {
            /* Bounded settle loop; do not use an unbounded helper here. */
        }
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* Clear the checked portion before the ETR is enabled. */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)AON_SRAM_BASE_ADDR + off, 0U);
    }

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

    /* Capture live ROM-table data without writing the debug aperture. */
    {
        uint32_t missing = 0U;
        uint32_t found_data[ACPU_CLUSTER_COUNT] = {0U};
        uint32_t found_addr[ACPU_CLUSTER_COUNT] = {0U};
        uint32_t data_off[ACPU_CLUSTER_COUNT][ACPU_CLUSTER_DUMP_WORDS];
        uint32_t addr_off[ACPU_CLUSTER_COUNT][ACPU_CLUSTER_DUMP_WORDS];

        acpu_debug_capture_pattern();

        /* Program and trigger crash_dump through the design register map. */
        crash_dump_config_and_trigger();

        /* One bounded SRAM scan marks every expected data/addr word. */
        for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
            uint32_t got = R32((uintptr_t)AON_SRAM_BASE_ADDR + off);

            for (uint32_t cluster = 0U; cluster < ACPU_CLUSTER_COUNT;
                 ++cluster) {
                for (uint32_t word = 0U; word < ACPU_CLUSTER_DUMP_WORDS;
                     ++word) {
                    if (((found_data[cluster] & (1U << word)) == 0U) &&
                        (got == acpu_expected_data[cluster][word])) {
                        found_data[cluster] |= (1U << word);
                        data_off[cluster][word] = off;
                    }

                    if (((found_addr[cluster] & (1U << word)) == 0U) &&
                        (got == (acpu_cluster_bases[cluster] + (word * 4U)))) {
                        found_addr[cluster] |= (1U << word);
                        addr_off[cluster][word] = off;
                    }
                }
            }
        }

        for (uint32_t cluster = 0U; cluster < ACPU_CLUSTER_COUNT;
             ++cluster) {
            for (uint32_t word = 0U; word < ACPU_CLUSTER_DUMP_WORDS;
                 ++word) {
                uint32_t want_data = acpu_expected_data[cluster][word];

                if (((found_data[cluster] & (1U << word)) == 0U) &&
                    (want_data != 0U)) {
                    ++missing;
                    c_uvm_error(
                        "acpu%0d dump data 0x%08x not found in AON SRAM",
                        cluster, want_data);
                }

                if ((found_addr[cluster] & (1U << word)) == 0U) {
                    ++missing;
                    c_uvm_error(
                        "acpu%0d dump address 0x%08x not found in AON SRAM",
                        cluster, acpu_cluster_bases[cluster] + (word * 4U));
                }
            }

            if (((found_data[cluster] & (1U << 0)) != 0U) &&
                ((found_addr[cluster] & (1U << 0)) != 0U)) {
                c_uvm_info(
                    "acpu%0d dump word 0x%08x at data 0x%08x addr 0x%08x",
                    cluster, acpu_expected_data[cluster][0],
                    AON_SRAM_BASE_ADDR + data_off[cluster][0],
                    AON_SRAM_BASE_ADDR + addr_off[cluster][0]);
            }
        }

        if (missing == 0U) {
            c_uvm_info("%s", "ACPU crash dump trace data check passed");
        }
    }

    C_PASS();
CPU_TEST_END
