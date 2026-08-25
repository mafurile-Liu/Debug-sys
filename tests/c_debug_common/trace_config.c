/*
 * trace_config.c
 *
 * IMPLEMENTATIONS for the AON and dbg_ss (SYS) CoreSight trace-tree startup.
 * Declarations are in drv_debug.h (which pulls in drv_common.h and
 * coresight_trace_regs.h).
 *
 * Register offsets verified against ARM official documents:
 *   - ARM 100806_0800_18 SoC-600 TRM (TMC 9.16/9.18, Replicator 9.9, CATU 9.12)
 *   - ARM DDI0528B (STM-500)
 *
 * Key facts from TRM:
 *   - Replicator IDFILTn: reset=0 = all IDs PASS (broadcast both ports);
 *     0xFF = discard all (disable port).  [9.9.1/9.9.2]
 *   - TMC Circular Buffer mode (MODE=0): write pointer wraps, keeps latest
 *     trace, no reader needed.  [9.16 STS.Full]
 *   - TMC BUFWM (9.16.12): full output asserts when fill level >=
 *     (MEM_SIZE - BUFWM). BUFWM = MEM_SIZE-1 -> full after 1st word.
 *     Programmed only in Disabled state, before CTL.TraceCaptEn=1.
 *   - CATU MODE: 0=pass-through, 1=translate. Registers writable only when
 *     CONTROL.ENABLE=0 and STATUS.READY=1.  [9.12]
 */

#include "drv_debug.h"

/* ----------------------------------------------------------------------
 * Enable a CoreSight Funnel and select one or more slave ports.
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
 * Configure Replicator ID filtering for both output ports.
 * filt = REPL_IDFILTER_PASS_ALL (0x00) -> port passes all ATB IDs
 * filt = REPL_IDFILTER_DISCARD_ALL (0xFF) -> port disabled (all IDs dropped)
 * Source: ARM 100806_0800_18 SoC-600 TRM, 9.9.1/9.9.2 IDFILT0/IDFILT1.
 * Default reset (0,0) = broadcast to both ports.
 * ---------------------------------------------------------------------- */
static void replicator_config(uint32_t base, uint8_t filt0, uint8_t filt1)
{
    W32(base + REPL_IDFILTER0, filt0);
    W32(base + REPL_IDFILTER1, filt1);
}

/* ----------------------------------------------------------------------
 * Configure CATU in translate mode with a software-provided scatter-list
 * address. Per TRM 9.12, MODE/SLADDR are writable only while ENABLE=0.
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.12 css600_catu.
 * ---------------------------------------------------------------------- */
static void catu_enable_translate(uint32_t base, uint32_t sladdr)
{
    W32(base + CATU_CONTROL, 0);                /* disable first */
    W32(base + CATU_MODE, CATU_MODE_TRANSLATE);
    W32(base + CATU_SLADDRLO, sladdr);          /* bits [31:12] */
    W32(base + CATU_SLADDRHI, 0U);
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);  /* enable last */
}

/* ----------------------------------------------------------------------
 * Configure CATU in pass-through mode (address passes straight through,
 * no scatter-list translation). ENABLE must be 0 while writing MODE.
 * ---------------------------------------------------------------------- */
static void catu_enable_passthrough(uint32_t base)
{
    W32(base + CATU_CONTROL, 0);
    W32(base + CATU_MODE, CATU_MODE_PASSTHROUGH);
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);
}

/* ----------------------------------------------------------------------
 * Configure a TMC in ETR mode.
 * Offsets per ARM SoC-600 css600_tmc_etr (100806_0800_18 TRM 9.18).
 * ETR writes are routed through CATU; buffer ADDRESS is DBALO/DBAHI.
 * Configures MODE/DBALO/DBAHI/AXICTL + RWP/RRP pointers per TRM 4.8.5.
 * No DBSIZE register (RAM size is RSZ, RO, hw-fixed). Start capture via
 * CTL.TraceCaptEn (caller responsibility).
 * ---------------------------------------------------------------------- */
static void tmc_etr_config(uint32_t base, uint32_t buf_addr, uint32_t buf_size)
{
    (void)buf_size;  /* css600_tmc_etr has no DBSIZE; RAM size is RSZ (RO) */
    W32(base + TMC_MODE,    TMC_MODE_ETR);
    W32(base + TMC_DBALO,   buf_addr);
    W32(base + TMC_DBAHI,   0U);
    W32(base + TMC_AXICTL,  TMC_AXICTL_DEFAULT);
    W32(base + TMC_RWP,     buf_addr);
    W32(base + TMC_RWPHI,   0U);
    W32(base + TMC_RRP,     buf_addr);
    W32(base + TMC_RRPHI,   0U);
}

/* ----------------------------------------------------------------------
 * Configure a TMC in on-chip Circular Buffer mode (ETF).
 * MODE=0 = Circular Buffer: write pointer wraps around top of RAM, keeps
 * the most recent trace. No reader needed during capture.
 * Source: ARM SoC-600 TRM 9.16 STS.Full ("wraps around the top of the buffer").
 * ---------------------------------------------------------------------- */
static void tmc_etf_config(uint32_t base)
{
    W32(base + TMC_MODE, TMC_MODE_HW_FIFO);
}

/* ----------------------------------------------------------------------
 * Configure a TMC (ETF) to assert the full output (-> full IRQ) as fast as
 * possible, for interrupt/error-path testing.
 * SW FIFO mode + BUFWM = MEM_SIZE-1: per TRM 9.16.12, the full output is
 * asserted after the first 32-bit word of trace is written. MEM_SIZE is read
 * from RSZ (RO). Then CTL.TraceCaptEn is set to start capture so that as
 * soon as the trace source flows, the full IRQ fires.
 * Source: ARM SoC-600 TRM 9.16.12 BUFWM, 9.16.7 CTL.
 * ---------------------------------------------------------------------- */
static void tmc_etf_full_int_config(uint32_t base)
{
    uint32_t mem_size = R32(base + TMC_RSZ);     /* RAM size in 32-bit words (RO) */
    W32(base + TMC_MODE,  TMC_MODE_SW_FIFO);    /* SW FIFO: full asserts at watermark */
    /* BUFWM = MEM_SIZE-1 -> full after 1 word; guard against RSZ==0 read error */
    W32(base + TMC_BUFWM, mem_size ? (mem_size - 1U) : 0U);
    W32(base + TMC_CTL,   TMC_CTL_TRACECAPTEN); /* start capture -> trace fills -> full IRQ */
}

/* ----------------------------------------------------------------------
 * AON trace tree startup.
 * Components: Funnel -> Replicator -> {ETF (port0), ETR->CATU (port1)}
 * Trace sources (per AON_SS架构.png): M52 ITM, M52 ETM, HiFi5s TRAX/ITM
 * ---------------------------------------------------------------------- */
void aon_trace_init(trace_mode_t mode,
                    uint32_t     funnel_slave_port_mask,
                    uint32_t     etr_buf_addr,
                    uint32_t     etr_buf_size,
                    uint32_t     catu_sladdr)
{
    c_uvm_info("aon_trace_init: mode=%d funnel_mask=0x%x",
               mode, funnel_slave_port_mask);

    funnel_enable(AON_FUNNEL_BASE, funnel_slave_port_mask);

    switch (mode) {
    case TRACE_MODE_ETF_ONCHIP:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_config(AON_ETF_BASE);
        break;

    case TRACE_MODE_ETR_CATU:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_DISCARD_ALL,
                          REPL_IDFILTER_PASS_ALL);
        catu_enable_translate(AON_CATU_BASE, catu_sladdr);
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_CATU_BYPASS:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_config(AON_ETF_BASE);
        catu_enable_passthrough(AON_CATU_BASE);
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_FULL_INT:
        /* route trace to ETF, configure ETF to fire full IRQ after 1 word */
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_full_int_config(AON_ETF_BASE);
        break;

    default:
        c_uvm_error("aon_trace_init: unsupported mode %d", mode);
        break;
    }
}

/* ----------------------------------------------------------------------
 * dbg_ss (SYS) trace tree startup.
 * Components: STM -> Funnel -> Replicator -> {ETF (port0), ETR->CATU (port1)}
 * Trace source (per AON_SS架构.png): STM
 * ---------------------------------------------------------------------- */
void dbg_ss_trace_init(trace_mode_t mode,
                       uint32_t     funnel_slave_port_mask,
                       uint32_t     etr_buf_addr,
                       uint32_t     etr_buf_size,
                       uint32_t     catu_sladdr)
{
    c_uvm_info("dbg_ss_trace_init: mode=%d funnel_mask=0x%x",
               mode, funnel_slave_port_mask);

    /* STM must be enabled before it can generate ATB trace packets.
     * Source: ARM DDI0528B, STM_TCSR register. */
    W32(SYS_STM_BASE + STM_TCSR, STM_TCSR_EN);

    funnel_enable(SYS_FUNNEL_BASE, funnel_slave_port_mask);

    switch (mode) {
    case TRACE_MODE_ETF_ONCHIP:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_config(SYS_ETF_BASE);
        break;

    case TRACE_MODE_ETR_CATU:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_DISCARD_ALL,
                          REPL_IDFILTER_PASS_ALL);
        catu_enable_translate(SYS_CATU_BASE, catu_sladdr);
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_CATU_BYPASS:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_config(SYS_ETF_BASE);
        catu_enable_passthrough(SYS_CATU_BASE);
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr, etr_buf_size);
        break;

    case TRACE_MODE_FULL_INT:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_full_int_config(SYS_ETF_BASE);
        break;

    default:
        c_uvm_error("dbg_ss_trace_init: unsupported mode %d", mode);
        break;
    }
}