/*
 * c_config_pmu_trace/main.cpp
 *
 * Configure the AON PMU as an AXI-bus-monitor trace source, enable it on
 * the AON trace tree, and generate DDR transactions so the PMU has traffic
 * to observe.
 *
 * PMU config base is taken from the design address map:
 *   internal 0xA20BA000, external CPU/SNOC view 0x020BA000.
 * The trace_en and mode register offsets are still design-specific; update
 * the reserved macros below before running the case.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

/* PMU config block on AON_CFG_APB. */
#define AON_PMU_CFG_BASE          0x020CA000U

/* TODO: fill these offsets/bit from the PMU register map before running. */
#define AON_PMU_TRACE_EN_OFF      0x00000004U
#define AON_PMU_MODE_OFF          0x0000001CU
#define AON_PMU_TRACE_EN_MASK     0x00000041U
#define AON_PMU_MODE_DEFAULT      0x00000005U

#define AON_PMU_TRACE_EN_REG \
    (AON_PMU_CFG_BASE + AON_PMU_TRACE_EN_OFF)
#define AON_PMU_MODE_REG \
    (AON_PMU_CFG_BASE + AON_PMU_MODE_OFF)

/*
 * AON funnel slave port 4 maps to AON_PMU in Debug_top_v0p8.drawio.png:
 *   port0 crash_dump, 1 M52_ITM, 2 M52_ETM, 3 HIFI5s, 4 AON_PMU, 5 AON_DBM.
 */
#define AON_PMU_FUNNEL_SLAVE_PORT 4U
#define AON_TRACE_FUNNEL_MASK     (1U << AON_PMU_FUNNEL_SLAVE_PORT)

/* Linear ETR capture in AON SRAM. */
#define AON_TRACE_BUF_ADDR        AON_SRAM_BASE_ADDR
#define AON_TRACE_BUF_SIZE        0x00010000U
#define AON_TRACE_MODE            TRACE_MODE_ETF_CATU_BYPASS

/* DDR0 is the bus target used to generate AXI traffic through AON. */
#define DDR0_BASE                 0x28000000U
#define DDR0_WORDS                32U
#define DDR0_PATTERN              0x504D5500U

/*
 * Generate DDR traffic through AP3 axi_ap_aon_bus. From the CPU-side C
 * program, use the internal debug-APB register window (0x4A00_7000) and
 * program TAR/DRW; TAR holds the DDR byte address and DRW performs the
 * 32-bit AXI data access. Do not issue DDR addresses with R32/W32 directly.
 */
#define AON_AXI_AP_BASE           0x4A007000U
#define AON_AXI_AP_CSW            (AON_AXI_AP_BASE + 0xD00U)
#define AON_AXI_AP_TAR            (AON_AXI_AP_BASE + 0xD04U)
#define AON_AXI_AP_DRW            (AON_AXI_AP_BASE + 0xD0CU)
#define AON_AXI_AP_IDR            (AON_AXI_AP_BASE + 0xDFCU)

/*
 * MEM-AP CSW: non-secure privileged data, normal non-cacheable system
 * domain, 32-bit transfer.
 */
#define AON_AXI_AP_CSW_PROT       (3U << 28)
#define AON_AXI_AP_CSW_CACHE      (2U << 24)
#define AON_AXI_AP_CSW_DOMAIN     (3U << 13)
#define AON_AXI_AP_CSW_SIZE32     2U

/* Small SRAM window checked after the trace path has been flushed. */
#define AON_SRAM_CHECK_BYTES      0x00000100U

static void aon_axi_ap_config(void)
{
    W32(AON_AXI_AP_CSW,
        AON_AXI_AP_CSW_PROT |
        AON_AXI_AP_CSW_CACHE |
        AON_AXI_AP_CSW_DOMAIN |
        AON_AXI_AP_CSW_SIZE32);
    c_uvm_info("aon axi-ap IDR=0x%08x", R32(AON_AXI_AP_IDR));
}

static void aon_axi_ap_write(uint32_t addr, uint32_t data)
{
    W32(AON_AXI_AP_TAR, addr);
    W32(AON_AXI_AP_DRW, data);
}

static uint32_t aon_axi_ap_read(uint32_t addr)
{
    W32(AON_AXI_AP_TAR, addr);
    return R32(AON_AXI_AP_DRW);
}

static void pmu_trace_config(uint32_t mode)
{
    c_uvm_info("PMU trace_en reg=0x%08x val=0x%08x",
               AON_PMU_TRACE_EN_REG, AON_PMU_TRACE_EN_MASK);
    c_uvm_info("PMU mode reg=0x%08x id val=0x%08x",
               AON_PMU_MODE_REG, mode);

    W32(AON_PMU_TRACE_EN_REG, AON_PMU_TRACE_EN_MASK);
    W32(AON_PMU_MODE_REG, mode);
}

static void ddr_traffic_generate(void)
{
    uint32_t word;

    for (word = 0U; word < DDR0_WORDS; ++word) {
        aon_axi_ap_write(DDR0_BASE + (word * 4U), DDR0_PATTERN + word);
    }

    for (word = 0U; word < DDR0_WORDS; ++word) {
        (void)aon_axi_ap_read(DDR0_BASE + (word * 4U));
    }
}

static void aon_sram_trace_data_check(void)
{
    uint32_t off;
    uint32_t got;

    for (off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        got = R32((uintptr_t)(AON_TRACE_BUF_ADDR + off));
        if (got != 0U) {
            c_uvm_info("AON SRAM trace check: first nonzero @0x%08x=0x%08x",
                       AON_TRACE_BUF_ADDR + off, got);
            return;
        }
    }

    c_uvm_error("%s", "AON SRAM trace check: no nonzero data found");
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    /*
     * Clear only the checked window before configuring the trace path.
     * The PMU trace source is enabled after the AON tree is ready so the
     * first generated packets are not dropped.
     */
    for (uint32_t off = 0U; off < AON_SRAM_CHECK_BYTES; off += 4U) {
        W32((uintptr_t)(AON_TRACE_BUF_ADDR + off), 0U);
    }

    aon_trace_init(AON_TRACE_MODE,
                   AON_TRACE_FUNNEL_MASK,
                   AON_TRACE_BUF_ADDR,
                   AON_TRACE_BUF_SIZE,
                   CATU_SLADDR_DEFAULT);

    pmu_trace_config(AON_PMU_MODE_DEFAULT);

    /*
     * Configure AP3 axi_ap_aon_bus before generating DDR traffic. Writes and
     * reads are both performed because the PMU monitors read and write bus
     * performance.
     */
    aon_axi_ap_config();
    ddr_traffic_generate();

    /* Drain any packet held by the upstream buffer, ETF, or ETR. */
    //aon_trace_flush();
    delay_us(1);

    /*
     * This is only a weak sanity check. Once the PMU ATB packet format is
     * known, replace this with an explicit packet/payload check.
     */
    aon_sram_trace_data_check();

    c_uvm_info("%s", "PMU trace config and DDR traffic generation done");
    C_PASS();
CPU_TEST_END
