/*
 * debug_ect_route_etf_full_multi_channel/main.cpp
 *
 * Configure a randomized AON ECT event fanout route:
 *
 *   ETF.full (CTI_AON event_in[0])
 *     -> 2..4 randomly selected CTM channels
 *     -> CTI_AON event_out[1] / ETF.trigin
 *     -> CTI_AON event_out[2] / ETF.flushin
 *
 * This case uses a small local PRNG so it does not depend on libc rand().
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

//#define ECT_MULTI_SEED          0x12345678
#define ECT_MULTI_CTI_BASE      AON_CTI_BASE
#define ECT_MULTI_SRC_IN        0U

#define ECT_MULTI_OUT0          1U
#define ECT_MULTI_OUT1          2U

#define ECT_MULTI_MIN_CH        2U
#define ECT_MULTI_MAX_CH        4U

static void ect_multi_write(uint32_t offset, uint32_t value)
{
    W32((uintptr_t)(ECT_MULTI_CTI_BASE + offset), value);
}

static uint32_t ect_multi_read(uint32_t offset)
{
    return R32((uintptr_t)(ECT_MULTI_CTI_BASE + offset));
}


/*
 * Seed from the build timestamp.  The Linux flow rebuilds the case per run,
 * so this gives a different channel set without needing libc time/rand.
 */
constexpr uint32_t ect_multi_build_seed(void)
{
    constexpr const char *t = __TIME__;
    uint32_t h = 2166136261U;

    for (uint32_t i = 0U; i < 8U; ++i) {
        if (t[i] == '\0') {
            break;
        }
        h ^= (uint32_t)t[i];
        h *= 16777619U;
    }

    return h;
}

#ifdef ECT_MULTI_SEED
static uint32_t ect_multi_prng_state = (uint32_t)(ECT_MULTI_SEED);
#else
static uint32_t ect_multi_prng_state = ect_multi_build_seed();
#endif

static uint32_t ect_multi_rand(void)
{
    uint32_t x = ect_multi_prng_state;

    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    ect_multi_prng_state = x;
    return x;
}

static uint32_t ect_multi_rand_channel_mask(void)
{
    uint32_t order[16U];
    uint32_t i;
    uint32_t j;
    uint32_t tmp;
    uint32_t num_ch;
    uint32_t mask = 0U;


    for (i = 0U; i < 16U; ++i) {
        order[i] = i;
    }

    /* Fisher-Yates shuffle so each selected channel is unique. */
    for (i = 0U; i < 15U; ++i) {
        j = i + (ect_multi_rand() % (16U - i));
        tmp = order[i];
        order[i] = order[j];
        order[j] = tmp;
    }

    num_ch = ECT_MULTI_MIN_CH +
             (ect_multi_rand() %
              (ECT_MULTI_MAX_CH - ECT_MULTI_MIN_CH + 1U));

    for (i = 0U; i < num_ch; ++i) {
        mask |= (1U << order[i]);
    }

    return mask;
}

static void ect_multi_configure(void)
{
    uint32_t ctrl;
    uint32_t gate;
    uint32_t inen0;
    uint32_t outen1;
    uint32_t outen2;
    uint32_t mask;

    ctrl = ect_multi_read(CTI_CONTROL);
    c_uvm_info("ect multi route: CONTROL before config = 0x%08x", ctrl);
    ect_multi_write(CTI_CONTROL, 0U);

    mask = ect_multi_rand_channel_mask();

    /* One input event fans out to the randomized channel set. */
    inen0 = mask;
    ect_multi_write(CTI_INEN(ECT_MULTI_SRC_IN), inen0);

    /* Both configured outputs observe the same randomized channel set. */
    outen1 = mask;
    outen2 = mask;
    ect_multi_write(CTI_OUTEN(ECT_MULTI_OUT0), outen1);
    ect_multi_write(CTI_OUTEN(ECT_MULTI_OUT1), outen2);

    /* All randomized channels are allowed through the CTI gate. */
    gate = mask;
    ect_multi_write(CTI_GATE, gate);

    ect_multi_write(CTI_CONTROL, CTI_CONTROL_EN);

    ctrl   = ect_multi_read(CTI_CONTROL);
    gate   = ect_multi_read(CTI_GATE);
    inen0  = ect_multi_read(CTI_INEN(ECT_MULTI_SRC_IN));
    outen1 = ect_multi_read(CTI_OUTEN(ECT_MULTI_OUT0));
    outen2 = ect_multi_read(CTI_OUTEN(ECT_MULTI_OUT1));

    c_uvm_info("ect multi route: CONTROL=0x%08x GATE=0x%08x INEN0=0x%08x OUTEN1=0x%08x OUTEN2=0x%08x",
               ctrl, gate, inen0, outen1, outen2);

    if ((ctrl & CTI_CONTROL_EN) == 0U ||
        gate != mask ||
        inen0 != mask ||
        outen1 != mask ||
        outen2 != mask) {
        c_uvm_error("%s", "ect multi route: CTI random multi-channel route readback mismatch");
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    ect_multi_configure();

    c_uvm_info("%s", "ect multi route: ETF.full -> random channel set -> ETF.trigin/flushin configured");
    C_PASS();
CPU_TEST_END
