/*
 * c_aon_ap_scan_abort/main.cpp
 *
 * Scan the AON debug APs through the internal AP register window and check
 * each AP IDR. After the scan, issue a DP abort through the DP ABORT
 * register and verify the DP is still usable.
 *
 * The internal view addresses come from dbg_address_mapping.xlsx:
 *   m1 apb_ap_apbic   0x4A00_3000
 *   m2 ahb_ap_m52     0x4A00_5000
 *   m3 axi_ap_aon_bus 0x4A00_7000
 *   m5 ahb_ap_gpu     0x4A00_B000
 *   m6 axi_ap_npu0    0x4A00_D000
 *   m7 axi_ap_npu1    0x4A00_F000
 *   m8 axi_ap_npu2    0x4A01_1000
 *   m9 axi_ap_npu3    0x4A01_3000
 *   m10 axi_ap_npu4   0x4A01_5000
 *   m11 axi_ap_npu5   0x4A01_7000
 *
 * The JTAG AP (m4) has no internal-view entry in the design map, so it is
 * intentionally not scanned here.
 */

#include <stdint.h>
#include "drv_common.h"
#include "drv_debug.h"

/* css600_dp register block. ABORT and DPIDR share offset 0x000. */
#define DP_BASE                    0x4A000000U
#define DP_ABORT_REG               DP_BASE
#define DP_DPIDR_REG               DP_BASE
#define DP_ABORT_DAPABORT          (1U << 0)
#define DP_ABORT_STKERRCLR         (1U << 2)
#define DP_ABORT_WDERRCLR          (1U << 3)
#define DP_ABORT_ORUNERRCLR        (1U << 4)
#define DP_ABORT_ALL               (DP_ABORT_DAPABORT | \
                                    DP_ABORT_STKERRCLR | \
                                    DP_ABORT_WDERRCLR | \
                                    DP_ABORT_ORUNERRCLR)

/* A generic AP IDR lives at +0xDFC in each logical AP register block. */
#define AP_IDR_OFFSET              0xDFCU

typedef struct {
    uint32_t       base;
    const char *   name;
} aon_ap_t;

static const aon_ap_t aon_ap_list[] = {
    {0x4A003000U, "apb_ap_apbic"},
    {0x4A005000U, "ahb_ap_m52"},
    {0x4A007000U, "axi_ap_aon_bus"},
    {0x4A00B000U, "ahb_ap_gpu"},
    {0x4A00D000U, "axi_ap_npu0"},
    {0x4A00F000U, "axi_ap_npu1"},
    {0x4A011000U, "axi_ap_npu2"},
    {0x4A013000U, "axi_ap_npu3"},
    {0x4A015000U, "axi_ap_npu4"},
    {0x4A017000U, "axi_ap_npu5"}
};

static void aon_ap_scan(void)
{
    unsigned int i;

    for (i = 0U; i < (sizeof(aon_ap_list) / sizeof(aon_ap_list[0]));
         ++i) {
        uint32_t idr = R32((uintptr_t)(aon_ap_list[i].base +
                                       AP_IDR_OFFSET));

        c_uvm_info("AP %s base=0x%08x IDR=0x%08x",
                   aon_ap_list[i].name, aon_ap_list[i].base, idr);

        if (idr == 0U) {
            c_uvm_error("AP %s IDR is zero, AP is missing",
                        aon_ap_list[i].name);
        }
    }
}

static void dp_abort_and_check(void)
{
    uint32_t dpidr_before;
    uint32_t dpidr_after;
    uint32_t ap1_idr_after;

    /*
     * DPIDR is the read view of the same address used by ABORT on write.
     * The RAO bit is a simple way to check that the DP is alive.
     */
    dpidr_before = R32((uintptr_t)DP_DPIDR_REG);
    c_uvm_info("DPIDR before abort = 0x%08x", dpidr_before);

    if ((dpidr_before & 1U) == 0U) {
        c_uvm_error("%s", "DPIDR.RAO is not set before DP abort");
    }

    c_uvm_info("write DP ABORT=0x%08x", DP_ABORT_ALL);
    W32((uintptr_t)DP_ABORT_REG, DP_ABORT_ALL);

    dpidr_after = R32((uintptr_t)DP_DPIDR_REG);
    c_uvm_info("DPIDR after abort = 0x%08x", dpidr_after);

    if ((dpidr_after & 1U) == 0U) {
        c_uvm_error("%s", "DPIDR.RAO is not set after DP abort");
    }

    ap1_idr_after = R32((uintptr_t)(aon_ap_list[0].base + AP_IDR_OFFSET));
    c_uvm_info("AP1 IDR after abort = 0x%08x", ap1_idr_after);

    if (ap1_idr_after == 0U) {
        c_uvm_error("%s", "AP1 IDR is zero after DP abort");
    }
}

CPU_TEST_START
    OPEN_DEBUG_CRG();

    // --------------- clks cfg finish ---------------- //

    aon_ap_scan();

    /*
     * The DP ABORT register is write-only. Writing all clear bits plus
     * DAPABORT aborts any in-flight AP transaction and clears sticky errors.
     */
    dp_abort_and_check();

    c_uvm_info("%s", "AON AP internal-view scan and DP abort done");
    C_PASS();
CPU_TEST_END
