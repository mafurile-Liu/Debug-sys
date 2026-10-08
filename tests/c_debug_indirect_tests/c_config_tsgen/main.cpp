/*
 * c_config_tsgen/main.cpp
 *
 * Timestamp Generator (css600_tsgen) smoke test.
 *
 * The TSGen generates periodic EVENT_P for the CTM (trace sync).
 * SoC-600 TRM does not have a dedicated TSGen programming section -
 * it is a simple component. This case:
 *   1. Reads CoreSight ID registers (CIDR0-3, DEVARCH, DEVTYPE) to
 *      verify the component is present and accessible.
 *   2. Reads and logs any control/status registers in the first 4KB
 *      page (0x00-0xFF) to discover the register map.
 *
 * Address: 0x0205_9000 (AON bus view, mirrors 0xA205_9000 on APB config bus)
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

#define TSGEN_BASE      0x02059000U

/* CoreSight ID register offsets (standard, all CoreSight components) */
#define CS_DEVID        0xFC8U
#define CS_DEVTYPE      0xFCCU
#define CS_PIDR4        0xFD0U
#define CS_PIDR0        0xFE0U
#define CS_CIDR0        0xFF0U

/* scan range for possible control registers */
#define TSGEN_SCAN_START 0x000U
#define TSGEN_SCAN_END   0x100U

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /* 1. CoreSight ID check: CIDR0 must be 0x0D for a CoreSight component */
    {
        uint32_t cidr0 = R32((uintptr_t)TSGEN_BASE + CS_CIDR0);
        uint32_t cidr1 = R32((uintptr_t)TSGEN_BASE + CS_CIDR0 + 0x4U);
        uint32_t cidr2 = R32((uintptr_t)TSGEN_BASE + CS_CIDR0 + 0x8U);
        uint32_t cidr3 = R32((uintptr_t)TSGEN_BASE + CS_CIDR0 + 0xCU);
        c_uvm_info("tsgen CIDR: 0=%02x 1=%02x 2=%02x 3=%02x",
                   cidr0, cidr1, cidr2, cidr3);
        if (cidr0 == 0x0DU) {
            c_uvm_info("%s", "tsgen: CoreSight component confirmed");
        } else {
            c_uvm_error("%s", "tsgen: CIDR0 != 0x0D, not a CoreSight component");
        }
    }

    /* 2. DEVARCH / DEVTYPE */
    {
        uint32_t devarch = R32((uintptr_t)TSGEN_BASE + 0xFBCU);
        uint32_t devtype = R32((uintptr_t)TSGEN_BASE + CS_DEVTYPE);
        c_uvm_info("tsgen DEVARCH=0x%08x DEVTYPE=0x%08x", devarch, devtype);
    }

    /* 3. PIDR for designer/part info */
    {
        uint32_t pidr0 = R32((uintptr_t)TSGEN_BASE + CS_PIDR0);
        uint32_t pidr4 = R32((uintptr_t)TSGEN_BASE + CS_PIDR4);
        c_uvm_info("tsgen PIDR0=0x%02x PIDR4=0x%02x", pidr0, pidr4);
    }

    /* 4. Scan the first 256 bytes for non-zero registers (discover map) */
    for (uint32_t off = TSGEN_SCAN_START; off < TSGEN_SCAN_END; off += 4U) {
        uint32_t val = R32((uintptr_t)TSGEN_BASE + off);
        if (val != 0U && val != 0xFFFFFFFFU) {
            c_uvm_info("tsgen reg[0x%03x] = 0x%08x", off, val);
        }
    }

    c_uvm_info("%s", "tsgen smoke done");
    C_PASS();
CPU_TEST_END
