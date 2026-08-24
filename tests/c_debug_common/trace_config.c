/*
 * trace_config.c
 *
 * Startup configuration for the AON and dbg_ss (SYS) CoreSight trace trees.
 *
 * Constraints confirmed by user:
 *   1. ETR must go through CATU (no direct-DRAM mode).
 *   2. CATU target address is hardware-fixed; software does not program
 *      the scatter-list address (SLADDRLO/HI). Only enable is required.
 *
 * Reference coding style:
 *   - tests/c_debug_direct_tests/main.cpp
 *   - Uses W32/R32, c_uvm_info/c_uvm_error from drv_common.h
 *
 * Register offsets are defined in coresight_trace_regs.h and verified against
 * ARM official documents (SoC-600 TRM 100806_0800_18 and DDI0528B).
 */

#include <stdint.h>
#include "drv_common.h"
#include "coresight_trace_regs.h"

/* ----------------------------------------------------------------------
 * Helper: enable a CoreSight Funnel and select one or more slave ports.
 * FUNNEL_CTRL[15:8] is a bit mask; multiple ATB sources can be merged.
 * Source: ARM IHI0029G + ARM 100806_0800_18 SoC-600 TRM.
 * ---------------------------------------------------------------------- */
static void funnel_enable(uint32_t base, uint32_t slave_port_mask)
{
    uint32_t ctrl = FUNNEL_CTRL_EN
                  | ((slave_port_mask & FUNNEL_CTRL_SLAVE_EN_MASK)
                     << FUNNEL_CTRL_SLAVE_EN_SHIFT);
    W32(base + FUNNEL_CTRL, ctrl);
}

/* ----------------------------------------------------------------------
 * Helper: route Replicator to one of its two ATB output ports.
 * port = 0 -> enable port 0, disable port 1
 * port = 1 -> disable port 0, enable port 1
 * Source: ARM IHI0029G + ARM CoreSight Replicator TRM.
 * ---------------------------------------------------------------------- */
static void replicator_route(uint32_t base, uint32_t port)
{
    if (port == 0) {
        W32(base + REPL_IDFILTER0, 0);                    /* all IDs to port 0 */
        W32(base + REPL_IDFILTER1, REPL_IDFILTER_DISABLE); /* port 1 off */
    } else {
        W32(base + REPL_IDFILTER0, REPL_IDFILTER_DISABLE); /* port 0 off */
        W32(base + REPL_IDFILTER1, 0);                    /* all IDs to port 1 */
    }
}

/* ----------------------------------------------------------------------
 * Helper: enable a hardware-fixed CATU.
 * The scatter-list / translation address is fixed by SoC integration,
 * so software only asserts CONTROL.ENABLE.
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.12 css600_catu.
 * ---------------------------------------------------------------------- */
static void catu_enable_fixed(uint32_t base)
{
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);
}

/* ----------------------------------------------------------------------
 * Helper: configure a TMC in ETR mode.
 * Offsets per ARM SoC-600 css600_tmc_etr (100806_0800_18 TRM 9.18).
 * ETR writes are routed through CATU; buffer ADDRESS is DBALO/DBAHI.
 * Configures MODE/DBALO/DBAHI/AXICTL + RWP/RRP pointers per TRM 4.8.5.
 * No DBSIZE register (RAM size is RSZ, RO, hw-fixed). Start capture via CTL.TraceCaptEn.
 * ---------------------------------------------------------------------- */
static void tmc_etr_config(uint32_t base, uint32_t buf_addr, uint32_t buf_size)
{
    /* Per ARM SoC-600 css600_tmc_etr usage model (TRM 4.8.5, ETR steps 5-7):
     *   MODE      = ETR mode
     *   DBALO/DBAHI = AXI buffer write address (low/high)
     *   AXICTL    = AXI control (SoC-specific; TMC_AXICTL_DEFAULT is a placeholder)
     *   RWP/RRP   = DBA   (write & read pointers = buffer base; TRM: RRP = RWP)
     *   RWPHI/RRPHI = DBAHI (high bits of the pointers)
     *   RSZ is read-only (hardware RAM size) -> not written; buf_size is unused.
     * NOTE: to actually START capture, the caller must set CTL.TraceCaptEn (TRM step 8). */
    W32(base + TMC_MODE,    TMC_MODE_ETR);
    W32(base + TMC_DBALO,   buf_addr);
    W32(base + TMC_DBAHI,   0U);
    W32(base + TMC_AXICTL,  TMC_AXICTL_DEFAULT);
    W32(base + TMC_RWP,     buf_addr);
    W32(base + TMC_RWPHI,   0U);
    W32(base + TMC_RRP,     buf_addr);
    W32(base + TMC_RRPHI,   0U);
    (void)buf_size;  /* css600_tmc_etr has no DBSIZE; RAM size is RSZ (RO, hw-fixed) */
}

/* ----------------------------------------------------------------------
 * Helper: configure a TMC in on-chip ETF (SW FIFO) mode.
 * TMC_MODE offset 0x028 per ARM SoC-600 css600_tmc_etr; mode encoding HWFIFO=0/SWFIFO=1/ETR=2.
 * ---------------------------------------------------------------------- */
static void tmc_etf_config(uint32_t base)
{
    W32(base + TMC_MODE, TMC_MODE_SW_FIFO);
}

/* ----------------------------------------------------------------------
 * AON trace tree startup.
 *
 * Components: Funnel -> ETF / Replicator -> ETR -> CATU
 * Trace sources (per AON_SS架构.png): M52 ITM, M52 ETM, HiFi5s TRAX/ITM
 *
 * Supported modes:
 *   TRACE_MODE_ETF_ONCHIP : funnel -> ETF (on-chip FIFO)
 *   TRACE_MODE_ETR_CATU   : funnel -> replicator -> ETR -> CATU -> DRAM
 *
 * funnel_slave_port_mask: bit mask of FUNNEL slave ports to enable.
 *   Example: 0x01 = port 0 only; 0x07 = ports 0,1,2.
 * ---------------------------------------------------------------------- */
void aon_trace_init(trace_mode_t mode,
                    uint32_t     funnel_slave_port_mask,
                    uint32_t     etr_buf_addr,
                    uint32_t     etr_buf_size)
{
    c_uvm_info("aon_trace_init: mode=%d funnel_mask=0x%x",
               mode, funnel_slave_port_mask);

    funnel_enable(AON_FUNNEL_BASE, funnel_slave_port_mask);

    switch (mode) {
    case TRACE_MODE_ETF_ONCHIP:
        replicator_route(AON_REPLICATOR_BASE, 0);   /* port 0 -> ETF */
        tmc_etf_config(AON_ETF_BASE);
        break;

    case TRACE_MODE_ETR_CATU:
        catu_enable_fixed(AON_CATU_BASE);
        replicator_route(AON_REPLICATOR_BASE, 1);   /* port 1 -> ETR -> CATU */
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_TPIU_OFFCHIP:
    default:
        c_uvm_error("aon_trace_init: unsupported mode %d (AON has no TPIU)", mode);
        break;
    }
}

/* ----------------------------------------------------------------------
 * dbg_ss (SYS) trace tree startup.
 *
 * Components: STM -> Funnel -> ETF / Replicator -> ETR -> CATU / TPIU
 * Trace source (per AON_SS架构.png): STM
 *
 * Supported modes:
 *   TRACE_MODE_ETF_ONCHIP   : STM -> funnel -> ETF
 *   TRACE_MODE_ETR_CATU     : STM -> funnel -> replicator -> ETR -> CATU -> DRAM
 *   TRACE_MODE_TPIU_OFFCHIP : STM -> funnel -> replicator -> TPIU (off-chip)
 * ---------------------------------------------------------------------- */
void dbg_ss_trace_init(trace_mode_t mode,
                       uint32_t     funnel_slave_port_mask,
                       uint32_t     etr_buf_addr,
                       uint32_t     etr_buf_size,
                       uint32_t     tpiu_port_size)
{
    c_uvm_info("dbg_ss_trace_init: mode=%d funnel_mask=0x%x",
               mode, funnel_slave_port_mask);

    /* STM must be enabled before it can generate ATB trace packets.
     * Source: ARM DDI0528B, STM_TCSR register. */
    W32(SYS_STM_BASE + STM_TCSR, STM_TCSR_EN);

    funnel_enable(SYS_FUNNEL_BASE, funnel_slave_port_mask);

    switch (mode) {
    case TRACE_MODE_ETF_ONCHIP:
        replicator_route(SYS_REPLICATOR_BASE, 0);   /* port 0 -> ETF */
        tmc_etf_config(SYS_ETF_BASE);
        break;

    case TRACE_MODE_ETR_CATU:
        catu_enable_fixed(SYS_CATU_BASE);
        replicator_route(SYS_REPLICATOR_BASE, 1);   /* port 1 -> ETR -> CATU */
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_TPIU_OFFCHIP:
        replicator_route(SYS_REPLICATOR_BASE, 1);   /* port 1 -> TPIU */

        /* Configure TPIU for parallel trace port output.
         * Offsets confirmed (css600_tpiu); FFCR bit defs (ENFCONT/FLUSHMAN) still need check. */
        W32(SYS_TPIU_BASE + TPIU_CSPSR, tpiu_port_size);
        W32(SYS_TPIU_BASE + TPIU_SPPR,  TPIU_SPPR_PARALLEL);
        W32(SYS_TPIU_BASE + TPIU_FFCR,
            TPIU_FFCR_ENFCONT | TPIU_FFCR_FLUSHMAN);
        break;

    default:
        c_uvm_error("dbg_ss_trace_init: unsupported mode %d", mode);
        break;
    }
}