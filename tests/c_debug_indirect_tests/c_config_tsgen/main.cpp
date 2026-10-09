/*
 * c_config_tsgen/main.cpp
 *
 * Timestamp Generator (css600_tsgen) smoke test.
 *
 * The TSGen has two AON access ports:
 *   - 0x0206_2000: APB5 Completer 0, control/config interface (RW)
 *   - 0x0206_3000: APB5 Completer 1, read-only counter/ID interface (RO)
 *
 * This case reads back config-port registers before/after configuration,
 * configures/enables the counter through the RW port, checks that writes to
 * the dedicated RO port are ignored, and reads the live counter through the
 * RO port. CoreSight ID registers are also read from the RO port.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

/* AON system-bus view from the design address map. */
#define TSGEN_CFG_BASE  0x02062000U
#define TSGEN_RD_BASE   0x02063000U

/* SoC-600 TRM 9.21/9.22: css600_tsgen APB5 Completer 0/1. */
#define TSGEN_CNTCR       0x000U
#define TSGEN_CNTSR       0x004U
#define TSGEN_CNTCVL      0x008U
#define TSGEN_CNTCVU      0x00CU
#define TSGEN_CNTFID0     0x020U
#define TSGEN_CNTCVLREAD  0x000U
#define TSGEN_CNTCVUREAD  0x004U

#define TSGEN_CNTCR_EN    (1U << 0)

/* Deliberately invalid values used to probe writes on the RO port. */
#define TSGEN_RO_PROBE_LO 0xDEADBEEFU
#define TSGEN_RO_PROBE_HI 0xCAFEBABEU

/* CoreSight ID register offsets (standard, all CoreSight components) */
#define CS_DEVID        0xFC8U
#define CS_DEVTYPE      0xFCCU
#define CS_PIDR4        0xFD0U
#define CS_PIDR0        0xFE0U
#define CS_CIDR0        0xFF0U

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* 1. Configure the counter through the RW/config APB interface. */
    {
        uint32_t ctrl;
        uint32_t pre_cntcr;
        uint32_t pre_cntsr;
        uint32_t pre_lo;
        uint32_t pre_hi;
        uint32_t pre_fid;
        uint32_t post_lo;
        uint32_t post_hi;
        uint32_t post_fid;

        /* Issue several reads on the RW/config port before changing state. */
        pre_cntcr = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR);
        pre_cntsr = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTSR);
        pre_lo = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVL);
        pre_hi = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVU);
        pre_fid = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTFID0);
        c_uvm_info("tsgen cfg pre-read: CNTCR=0x%08x CNTSR=0x%08x",
                   pre_cntcr, pre_cntsr);
        c_uvm_info("tsgen cfg pre-read: CNTCV=0x%08x_%08x CNTFID0=0x%08x",
                   pre_hi, pre_lo, pre_fid);

        /* Stop the counter before changing CNTCVL/CNTCVU. */
        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR, 0U);

        /*
         * Seed the 64-bit counter. TRM requires CNTCVL first, then CNTCVU;
         * the timestamp updates on the CNTCVU write.
         */
        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVL, 0x10000000U);
        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVU, 0U);

        /* Enable counting. HDBG remains 0. */
        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR, TSGEN_CNTCR_EN);

        /* Read back several config-port registers after programming. */
        ctrl = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR);
        post_lo = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVL);
        post_hi = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVU);
        post_fid = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTFID0);

        c_uvm_info("tsgen CNTCR=0x%08x CNTSR=0x%08x",
                   ctrl, R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTSR));
        c_uvm_info("tsgen cfg post-read: CNTCV=0x%08x_%08x CNTFID0=0x%08x",
                   post_hi, post_lo, post_fid);
        if ((ctrl & TSGEN_CNTCR_EN) == 0U) {
            c_uvm_error("%s", "tsgen: CNTCR.EN did not read back as enabled");
        }
    }

    /*
     * 2. Check that the dedicated read-only port ignores writes.
     * Stop the counter first so the reference value cannot advance while the
     * invalid RO-port writes are issued. CNTCVL/CNTCVU on the config port are
     * the real counter state, so they are used as the reference after the
     * write attempts.
     */
    {
        uint32_t pre_lo;
        uint32_t pre_hi;
        uint32_t post_lo;
        uint32_t post_hi;

        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR, 0U);
        pre_lo = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVL);
        pre_hi = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVU);

        /*
         * The RO interface exposes CNTCVLREAD/CNTCVUREAD at 0x000/0x004.
         * These writes must not modify the TSGen counter state.
         */
        W32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVLREAD, TSGEN_RO_PROBE_LO);
        W32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVUREAD, TSGEN_RO_PROBE_HI);

        post_lo = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVL);
        post_hi = R32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCVU);

        c_uvm_info("tsgen RO write check: 0x%08x_%08x -> 0x%08x_%08x",
                   pre_hi, pre_lo, post_hi, post_lo);
        if ((pre_lo != post_lo) || (pre_hi != post_hi)) {
            c_uvm_error("%s", "tsgen: write to dedicated RO port changed counter state");
        }

        /* Restore the enabled state for the live-counter check below. */
        W32((uintptr_t)TSGEN_CFG_BASE + TSGEN_CNTCR, TSGEN_CNTCR_EN);
    }

    /* 3. Read the live counter through the dedicated read-only interface. */
    {
        uint32_t lo0 = R32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVLREAD);
        uint32_t hi0 = R32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVUREAD);
        volatile uint32_t spin;
        uint64_t before;
        uint64_t after;
        bool wrapped;

        for (spin = 0U; spin < 64U; ++spin) {
            /* Give the counter some cycles to advance. */
        }

        uint32_t lo1 = R32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVLREAD);
        uint32_t hi1 = R32((uintptr_t)TSGEN_RD_BASE + TSGEN_CNTCVUREAD);

        before = ((uint64_t)hi0 << 32U) | lo0;
        after = ((uint64_t)hi1 << 32U) | lo1;
        wrapped = (before == UINT64_MAX) && (after == 0U);

        c_uvm_info("tsgen counter: 0x%08x_%08x -> 0x%08x_%08x",
                   hi0, lo0, hi1, lo1);

        if ((after <= before) && !wrapped) {
            c_uvm_error("tsgen: RO counter did not increment (0x%08x_%08x -> 0x%08x_%08x)",
                        hi0, lo0, hi1, lo1);
        }
    }

    /* 4. CoreSight ID check through the read-only interface. */
    {
        uint32_t cidr0 = R32((uintptr_t)TSGEN_RD_BASE + CS_CIDR0);
        uint32_t cidr1 = R32((uintptr_t)TSGEN_RD_BASE + CS_CIDR0 + 0x4U);
        uint32_t cidr2 = R32((uintptr_t)TSGEN_RD_BASE + CS_CIDR0 + 0x8U);
        uint32_t cidr3 = R32((uintptr_t)TSGEN_RD_BASE + CS_CIDR0 + 0xCU);
        uint32_t pidr0 = R32((uintptr_t)TSGEN_RD_BASE + CS_PIDR0);
        uint32_t pidr4 = R32((uintptr_t)TSGEN_RD_BASE + CS_PIDR4);

        c_uvm_info("tsgen PIDR0=0x%02x PIDR4=0x%02x", pidr0, pidr4);
        c_uvm_info("tsgen CIDR: 0=%02x 1=%02x 2=%02x 3=%02x",
                   cidr0, cidr1, cidr2, cidr3);
        if (cidr0 == 0x0DU) {
            c_uvm_info("%s", "tsgen: CoreSight component confirmed");
        } else {
            c_uvm_error("%s", "tsgen: CIDR0 != 0x0D, not a CoreSight component");
        }
    }

    c_uvm_info("%s", "tsgen smoke done");
    C_PASS();
CPU_TEST_END
