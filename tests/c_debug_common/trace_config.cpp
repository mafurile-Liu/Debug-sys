/*
 * trace_config.cpp
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
 *   - CATU MODE: 0=pass-through, 1=translate. Registers writable only when
 *     CONTROL.ENABLE=0 and STATUS.READY=1.  [9.12]
 *   - CATU INADDRLO/INADDRHI (9.12.7/9.12.8): valid input VA range lower
 *     bound (INADDRLO bits [31:20], 1MB granularity). VA < INADDR or
 *     VA > INADDR+size -> STATUS.ADDRERR -> IRQ. Applies in BOTH modes.
 */

#include "drv_debug.h"

/* ---------------------------------------------------------------------- */
/* HiFi5s TRAX -> ATB output control.                                      */
/* ---------------------------------------------------------------------- */

void hifi_trace_atb_start(uint8_t atid, uint8_t smper, bool enable_trace_ram)
{
    uint32_t ctrl = TRAXCTRL_ATEN;

    ctrl |= static_cast<uint32_t>(atid & TRAXCTRL_ATID_MASK)
            << TRAXCTRL_ATID_SHIFT;
    ctrl |= static_cast<uint32_t>(smper & TRAXCTRL_SMPER_MASK)
            << TRAXCTRL_SMPER_SHIFT;

    if (enable_trace_ram) {
        ctrl |= TRAXCTRL_TMEN;
    }

    ctrl |= TRAXCTRL_TREN;

    W32(HIFI_TRAX_BASE + HIFI_TRAXCTRL, 0U);
    W32(HIFI_TRAX_BASE + HIFI_TRAXADDR, 0U);
    W32(HIFI_TRAX_BASE + HIFI_TRAXCTRL, ctrl);
}

void hifi_trace_atb_stop(void)
{
    uint32_t ctrl = R32(HIFI_TRAX_BASE + HIFI_TRAXCTRL);
    ctrl |= TRAXCTRL_TRSTP;
    W32(HIFI_TRAX_BASE + HIFI_TRAXCTRL, ctrl);

    /* Wait for TRAXSTAT.TRACT to clear before returning. */
    uint32_t timeout = 100000U;
    while ((hifi_trace_atb_status() & TRAXSTAT_TRACT) != 0U) {
        if (timeout == 0U) {
            c_uvm_error("hifi_trace_atb_stop: trace did not stop");
            return;
        }
        --timeout;
    }
}

uint32_t hifi_trace_atb_status(void)
{
    return R32(HIFI_TRAX_BASE + HIFI_TRAXSTAT);
}

/* ----------------------------------------------------------------------
 * Enable a CoreSight Funnel and select one or more slave ports.
 * FUNNELCONTROL[7:0] is the receiver-interface enable mask.
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.8.1.
 * ---------------------------------------------------------------------- */
static void funnel_enable(uint32_t base, uint32_t slave_port_mask)
{
    uint32_t ctrl = R32(base + FUNNEL_CTRL);
    ctrl &= ~FUNNEL_CTRL_RX_EN_MASK;
    ctrl |= (slave_port_mask & FUNNEL_CTRL_RX_EN_MASK)
            << FUNNEL_CTRL_RX_EN_SHIFT;
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
 * address AND the valid input VA range covering the ETR buffer base.
 * Per TRM 9.12, MODE/SLADDR/INADDR are writable only while ENABLE=0.
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.12 css600_catu.
 * ---------------------------------------------------------------------- */
static void catu_enable_translate(uint32_t base, uint32_t sladdr, uint32_t buf_addr)
{
    W32(base + CATU_CONTROL, 0);                /* disable first */
    W32(base + CATU_MODE, CATU_MODE_TRANSLATE);
    W32(base + CATU_SLADDRLO, sladdr);          /* scatter list base */
    W32(base + CATU_SLADDRHI, 0U);
    W32(base + CATU_INADDRLO, buf_addr);        /* valid VA range lower bound */
    W32(base + CATU_INADDRHI, 0U);
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);  /* enable last */
}

/* ----------------------------------------------------------------------
 * Configure CATU in pass-through mode (address passes straight through,
 * no scatter-list translation). INADDR still validates the input range,
 * so it must cover the ETR buffer base to avoid ADDRERR.
 * ---------------------------------------------------------------------- */
static void catu_enable_passthrough(uint32_t base, uint32_t buf_addr)
{
    W32(base + CATU_CONTROL, 0);
    W32(base + CATU_MODE, CATU_MODE_PASSTHROUGH);
    W32(base + CATU_INADDRLO, buf_addr);        /* valid VA range lower bound */
    W32(base + CATU_INADDRHI, 0U);
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);
}

/* ----------------------------------------------------------------------
 * Configure CATU to deliberately trigger ADDRERR: INADDR set to a range
 * that does NOT cover the ETR buffer base (1MB above it), so the first
 * ETR write is out of range -> STATUS.ADDRERR -> IRQ.
 * ---------------------------------------------------------------------- */
static void catu_enable_addrerr(uint32_t base, uint32_t buf_addr)
{
    W32(base + CATU_CONTROL, 0);
    W32(base + CATU_MODE, CATU_MODE_PASSTHROUGH);
    /* INADDR = buf_addr + 1MB: any write to buf_addr is below the lower
     * bound -> ADDRERR. INADDRLO field is [31:20] (1MB granularity). */
    W32(base + CATU_INADDRLO, buf_addr + 0x00100000U);
    W32(base + CATU_INADDRHI, 0U);
    W32(base + CATU_CONTROL, CATU_CONTROL_EN);
}

/* ----------------------------------------------------------------------
 * Real circular-buffer capacity of a TMC.
 * The CB wrap/full point is RSZ*4 bytes (RSZ is read-only, hw-fixed).`n * In CB mode STS.Full sets when RWP wraps
 * this top, the FULL output drives the buffer IRQ, and Full stays set until
 * it is written 0 in Disabled state (TraceCaptEn=0). Capture keeps running
 * and overwrites old trace.
 * Source: ARM SoC-600 TRM 9.18.2 STS (p837), 9.18.16 RSZ.
 * ---------------------------------------------------------------------- */
static uint32_t tmc_capacity_bytes(uint32_t base)
{
    return R32(base + TMC_RSZ) * 4U;
}

/* ----------------------------------------------------------------------
 * Configure a TMC in ETR mode.
 * Offsets per ARM SoC-600 css600_tmc_etr (100806_0800_18 TRM 9.18).
 * ETR writes are routed through CATU; buffer ADDRESS is DBALO/DBAHI.
 * Configures MODE/DBALO/DBAHI/AXICTL + RWP/RRP pointers per TRM 4.8.5.
 * No DBSIZE register (RAM size is RSZ, RO, hw-fixed). Start capture via
 * CTL.TraceCaptEn (caller responsibility).
 * ---------------------------------------------------------------------- */
static void tmc_etr_config(uint32_t base, uint32_t buf_addr)
{

    /* CB wrap point = RSZ*4 bytes. When RWP wraps this top, STS.Full sets and
     * the FULL output drives the buffer IRQ - expected in CB mode, capture
     * keeps overwriting. Full clears only in Disabled state (TraceCaptEn=0). */
    c_uvm_info("tmc_etr_config: CB capacity RSZ*4 = %0d bytes",
               tmc_capacity_bytes(base));
    W32(base + TMC_MODE,    TMC_MODE_CIRCULAR_BUFFER);
    W32(base + TMC_DBALO,   buf_addr);
    W32(base + TMC_DBAHI,   0U);
    W32(base + TMC_AXICTL,  TMC_AXICTL_DEFAULT);
    W32(base + TMC_RWP,     buf_addr);
    W32(base + TMC_RWPHI,   0U);
    W32(base + TMC_RRP,     buf_addr);
    W32(base + TMC_RRPHI,   0U);
    W32(base + TMC_CTL,     TMC_CTL_TRACECAPTEN);
}

/* ----------------------------------------------------------------------
 * Configure a TMC in on-chip Circular Buffer mode (ETF).
 * MODE=0 = Circular Buffer: write pointer wraps, keeps latest trace.
 * Source: ARM SoC-600 TRM 9.16 STS.Full.
 * ---------------------------------------------------------------------- */
static void tmc_etf_config(uint32_t base)
{
    W32(base + TMC_MODE, TMC_MODE_CIRCULAR_BUFFER);
    W32(base + TMC_CTL,  TMC_CTL_TRACECAPTEN);
}

static void tmc_etf_hw_fifo_config(uint32_t base)
{
    W32(base + TMC_MODE, TMC_MODE_HARDWARE_FIFO);
    W32(base + TMC_BUFWM, 0U);
    W32(base + TMC_RWP, 0U);
    W32(base + TMC_RRP, 0U);
    W32(base + TMC_FFCR, TMC_FFCR_ENTI | TMC_FFCR_ENFT);
    W32(base + TMC_CTL,  TMC_CTL_TRACECAPTEN);
}

/* ----------------------------------------------------------------------
 * Configure a TMC (ETF) to assert the full output (-> full IRQ) as fast
 * as possible. SW FIFO + BUFWM=MEM_SIZE-1: full after 1 word.
 * Source: ARM SoC-600 TRM 9.16.12 BUFWM, 9.16.7 CTL.
 * ---------------------------------------------------------------------- */
static void tmc_etr_swf1_full_int_config(uint32_t base, uint32_t buf_addr)
{
    uint32_t mem_size = R32(base + TMC_RSZ);     /* RAM size in 32-bit words (RO) */

    W32(base + TMC_MODE,  TMC_MODE_SOFTWARE_FIFO_1);
    W32(base + TMC_DBALO, buf_addr);
    W32(base + TMC_DBAHI, 0U);
    W32(base + TMC_AXICTL, TMC_AXICTL_DEFAULT);
    W32(base + TMC_RWP,   buf_addr);
    W32(base + TMC_RWPHI, 0U);
    W32(base + TMC_RRP,   buf_addr);
    W32(base + TMC_RRPHI, 0U);
    W32(base + TMC_BUFWM, mem_size ? (mem_size - 1U) : 0U);
    W32(base + TMC_CTL,   TMC_CTL_TRACECAPTEN); /* start capture -> full IRQ */
}

/* ----------------------------------------------------------------------
 * Enable crash_dump as a trace source.
 * Crash_dump is currently modeled as an ATB source into AON_FUNNEL slave
 * port 0. Internal crash_dump registers are not configured here; add them
 * when the HDD provides the register map.
 * ---------------------------------------------------------------------- */
void crash_dump_start(void)
{
    c_uvm_info("crash_dump_start: base=0x%08x funnel_port=%0d",
               AON_CRASH_DUMP_BASE,
               AON_CRASH_DUMP_FUNNEL_SLAVE_PORT);

    funnel_enable(AON_FUNNEL_BASE,
                  1U << AON_CRASH_DUMP_FUNNEL_SLAVE_PORT);
}

/* ----------------------------------------------------------------------
 * AON trace tree startup.
 * Components: Funnel -> Replicator -> {ETF (port0), ETR->CATU (port1)}
 * Trace sources (per AON_SS架构.png):
 *   - M52 ITM
 *   - M52 ETM
 *   - HiFi5s TRAX/ITM
 *   - crash_dump, on AON_FUNNEL slave port 0
 * ---------------------------------------------------------------------- */
void aon_trace_init(trace_mode_t mode,
                    uint32_t     funnel_slave_port_mask,
                    uint32_t     etr_buf_addr,
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

    case TRACE_MODE_ETF_ATB_ONLY:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_hw_fifo_config(AON_ETF_BASE);
        break;

    case TRACE_MODE_ETF_CATU_TRANSLATE:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(AON_ETF_BASE);
        catu_enable_translate(AON_CATU_BASE, catu_sladdr, etr_buf_addr);
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_ETF_CATU_BYPASS:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(AON_ETF_BASE);
        catu_enable_passthrough(AON_CATU_BASE, etr_buf_addr);
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_ETR_SWF1_FULL_INT:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(AON_ETF_BASE);
        tmc_etr_swf1_full_int_config(AON_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_CATU_ADDRERR:
        replicator_config(AON_REPLICATOR_BASE,
                          REPL_IDFILTER_DISCARD_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_config(AON_ETF_BASE);
        catu_enable_addrerr(AON_CATU_BASE, etr_buf_addr);
        tmc_etr_config(AON_ETR_BASE, etr_buf_addr);
        W32(AON_ETR_BASE + TMC_CTL, TMC_CTL_TRACECAPTEN); /* start -> ADDRERR */
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

    case TRACE_MODE_ETF_ATB_ONLY:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_DISCARD_ALL);
        tmc_etf_hw_fifo_config(SYS_ETF_BASE);
        break;

    case TRACE_MODE_ETF_CATU_TRANSLATE:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(SYS_ETF_BASE);
        catu_enable_translate(SYS_CATU_BASE, catu_sladdr, etr_buf_addr);
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_ETF_CATU_BYPASS:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(SYS_ETF_BASE);
        catu_enable_passthrough(SYS_CATU_BASE, etr_buf_addr);
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_ETR_SWF1_FULL_INT:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_PASS_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_hw_fifo_config(SYS_ETF_BASE);
        tmc_etr_swf1_full_int_config(SYS_ETR_BASE, etr_buf_addr);
        break;

    case TRACE_MODE_CATU_ADDRERR:
        replicator_config(SYS_REPLICATOR_BASE,
                          REPL_IDFILTER_DISCARD_ALL,
                          REPL_IDFILTER_PASS_ALL);
        tmc_etf_config(SYS_ETF_BASE);
        catu_enable_addrerr(SYS_CATU_BASE, etr_buf_addr);
        tmc_etr_config(SYS_ETR_BASE, etr_buf_addr);
        W32(SYS_ETR_BASE + TMC_CTL, TMC_CTL_TRACECAPTEN); /* start -> ADDRERR */
        break;

    default:
        c_uvm_error("dbg_ss_trace_init: unsupported mode %d", mode);
        break;
    }
}
