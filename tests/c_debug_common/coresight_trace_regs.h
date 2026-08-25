/*
 * coresight_trace_regs.h
 *
 * Register map header for the CoreSight trace components on the
 * AON and dbg_ss (SYS) trace trees.
 *
 * Base addresses come from:
 *   - dbg_address_mapping.xlsx
 *   - openocd-sim-v0.2.0/tests/ocd_common/addr_defs.tcl
 *
 * Register offsets are verified against ARM official documents
 * (SoC-600 TRM 100806_0800_18 and DDI0528B); see per-register comments.
 *
 * References:
 *   - ARM IHI0029G: CoreSight v3.0 Architecture Specification
 *   - ARM 100806_0800_18: CoreSight SoC-600 Technical Reference Manual
 *   - ARM DDI0528B: CoreSight STM-500 System Trace Macrocell TRM
 */

#ifndef CORESIGHT_TRACE_REGS_H
#define CORESIGHT_TRACE_REGS_H

#include <stdint.h>

/* ======================================================================
 * Component base addresses (from dbg_address_mapping.xlsx / addr_defs.tcl)
 * ====================================================================== */

/* AON trace tree (APBIC_DBG_AON expander0)
 * Trace sources (per AON_SS架构.png): M52 ITM, M52 ETM, HiFi5s TRAX/ITM */
#define AON_FUNNEL_BASE      0x4A202000U
#define AON_ETF_BASE         0x4A203000U
#define AON_REPLICATOR_BASE  0x4A204000U
#define AON_ETR_BASE         0x4A205000U
#define AON_CATU_BASE        0x4A206000U

/* SYS / dbg_ss trace tree (APBIC_SYS_DBG expander1)
 * Trace source (per AON_SS架构.png): STM */
#define SYS_STM_BASE         0x4A400000U
#define SYS_FUNNEL_BASE      0x4A402000U
#define SYS_ETF_BASE         0x4A403000U
#define SYS_REPLICATOR_BASE  0x4A404000U
#define SYS_ETR_BASE         0x4A405000U
#define SYS_CATU_BASE        0x4A406000U
#define SYS_TPIU_BASE        0x4A407000U

/* ======================================================================
 * CoreSight Funnel (CSTF)
 * Source: ARM IHI0029G + ARM 100806_0800_18 SoC-600 TRM
 * FUNNEL_CTRL[15:8] is a bit mask; multiple slave ports can be enabled
 * simultaneously.
 * ====================================================================== */
#define FUNNEL_CTRL            0x000U
#define FUNNEL_PSCR            0x004U

#define FUNNEL_CTRL_EN         (1U << 0)
#define FUNNEL_CTRL_MINHT_SHIFT     1
#define FUNNEL_CTRL_SLAVE_EN_SHIFT  8
#define FUNNEL_CTRL_SLAVE_EN_MASK   0xFFU
#define FUNNEL_CTRL_HT_SHIFT       16

/* ======================================================================
 * CoreSight TMC (Trace Memory Controller) - ETF / ETR
 * Source: ARM CoreSight TMC TRM (component may be css600_tmc or vendor variant)
 * Offsets verified against ARM SoC-600 css600_tmc_etr register summary
 * (100806_0800_18 TRM, section 9.18). Standard SoC-600 css600_tmc map:
 *   RSZ 0x004  STS 0x00c  RRD 0x010  RRP 0x014  RWP 0x018  TRG 0x01c
 *   CTL 0x020  RWD 0x024  MODE 0x028  LBUFLEVEL 0x02c  CBUFLEVEL 0x030
 *   AXICTL 0x110  DBALO 0x118  DBAHI 0x11c  RURP 0x120
 * ====================================================================== */
#define TMC_RSZ                0x004U  /* ARM SoC-600 css600_tmc_etr: RAM Size (RO) */
#define TMC_STS                0x00cU  /* ARM SoC-600 css600_tmc_etr: Status */
#define TMC_MODE               0x028U  /* ARM SoC-600 css600_tmc_etr: Mode */
#define TMC_LBUFLEVEL          0x02cU  /* ARM SoC-600 css600_tmc_etr: Latched Buffer Fill Level (RO) */
#define TMC_CBUFLEVEL          0x030U  /* ARM SoC-600 css600_tmc_etr: Current Buffer Fill Level (RO); was misnamed CBSIZE */
#define TMC_BUFWM             0x034U  /* ARM SoC-600 css600_tmc: Buffer Level Water Mark (SW FIFO/HWF) */
#define TMC_AXICTL             0x110U  /* ARM SoC-600 css600_tmc_etr: AXI Control; was AXICTRL */
#define TMC_DBALO              0x118U  /* ARM SoC-600 css600_tmc_etr: Data Buffer Address Low */
#define TMC_DBAHI              0x11cU  /* ARM SoC-600 css600_tmc_etr: Data Buffer Address High */
/* TMC_DBSIZE removed: css600_tmc_etr has no DBSIZE register; RAM size is RSZ (RO, hw-fixed). */

/* Additional css600_tmc_etr registers for a complete ETR setup (TRM 4.8.5):
 *   RWP/RWP_HI = RAM write pointer; for ETR, RWP = DBA (buffer base addr).
 *   RRP/RRP_HI = RAM read pointer; TRM recommends RRP = RWP.
 *   CTL.TraceCaptEn (bit0) must be set to actually start trace capture. */
#define TMC_CTL                 0x020U  /* ARM SoC-600 css600_tmc_etr: Control Register */
#define TMC_RRP                 0x014U  /* RAM Read Pointer */
#define TMC_RWP                 0x018U  /* RAM Write Pointer */
#define TMC_RRPHI               0x038U  /* RAM Read Pointer High */
#define TMC_RWPHI               0x03cU  /* RAM Write Pointer High */
#define TMC_CTL_TRACECAPTEN     (1U << 0)  /* CTL bit0: set to START trace capture (TRM 4.8.5 step 8) */
#define TMC_AXICTL_DEFAULT      0x00000000U  /* placeholder; program per SoC AXI integration (burst/AxCACHE/AxPROT) */

#define TMC_MODE_HW_FIFO       0x00000000U
#define TMC_MODE_SW_FIFO       0x00000001U
#define TMC_MODE_ETR           0x00000002U

/* ======================================================================
 * CoreSight Replicator
 * Source: ARM IHI0029G + ARM 100806_0800_18 SoC-600 TRM
 * ====================================================================== */
#define REPL_IDFILTER0         0x000U
#define REPL_IDFILTER1         0x004U
#define REPL_IDFILTER_PASS_ALL    0x00U  /* all ATB IDs pass to this port (reset/default = broadcast) */
#define REPL_IDFILTER_DISCARD_ALL 0xFFU  /* all ATB IDs discarded -> port disabled */

/* ======================================================================
 * CoreSight TPIU
 * Source: ARM 100806_0800_18 SoC-600 TRM
 * ====================================================================== */
#define TPIU_SSPSR             0x000U  /* ARM SoC-600 css600_tpiu: Supported Port Size */
#define TPIU_CSPSR             0x004U  /* ARM SoC-600 css600_tpiu: Current Port Size */
#define TPIU_ACPR              0x010U  /* ARM SoC-600 css600_tpiu: Async Clock Prescaler */
#define TPIU_SPPR             0x0F0U  /* ARM SoC-600 css600_tpiu: Selected Pin Protocol; was WRONG 0x300 (=FFSR) */
#define TPIU_FFCR              0x304U  /* ARM SoC-600 css600_tpiu: Formatter and Flush Control */

#define TPIU_SPPR_PARALLEL     0x00000000U
#define TPIU_SPPR_SWO_NRZ      0x00000001U
#define TPIU_SPPR_SWO_MANCHESTER 0x00000002U

#define TPIU_FFCR_ENFCONT      (1U << 1)
#define TPIU_FFCR_FLUSHMAN     (1U << 6)   /* FOnMan: manual flush trigger, bit6 (TRM css600_tpiu FFCR); was WRONG bit12 */

/* ======================================================================
 * CoreSight STM-500 (System Trace Macrocell)
 * Source: ARM DDI0528B
 * ====================================================================== */
#define STM_TCSR               0xE80U  /* ARM DDI0528B STMTCSR; was WRONG 0x000 */
#define STM_SYNCR              0xE90U  /* ARM DDI0528B STMSYNCR; was WRONG 0x00C */

#define STM_TCSR_EN            (1U << 0)

/* ======================================================================
 * CoreSight CATU (CoreSight Address Translation Unit)
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.12 css600_catu
 * ====================================================================== */
#define CATU_CONTROL           0x000U
#define CATU_MODE              0x004U
#define CATU_AXICTRL           0x008U
#define CATU_IRQEN             0x00CU
#define CATU_SLADDRLO          0x020U  /* Scatter List Address Low  */
#define CATU_SLADDRHI          0x024U  /* Scatter List Address High */
#define CATU_INADDRLO          0x028U  /* Input (valid VA range) Low  */
#define CATU_INADDRHI          0x02CU  /* Input (valid VA range) High */
#define CATU_STATUS            0x100U

#define CATU_CONTROL_EN        (1U << 0)
#define CATU_MODE_PASSTHROUGH  0x00000000U
#define CATU_SLADDR_DEFAULT   0x27400000U  /* default CATU scatter-list address (4KB-aligned) */
#define CATU_MODE_TRANSLATE    0x00000001U

/* ======================================================================
 * Trace startup mode selectors
 * ====================================================================== */
typedef enum {
    TRACE_MODE_ETF_ONCHIP = 0,   /* source -> funnel -> ETF (on-chip FIFO) */
    TRACE_MODE_ETR_CATU   = 1,   /* source -> funnel -> replicator -> ETR -> CATU -> DRAM */
    TRACE_MODE_CATU_BYPASS  = 2,  /* funnel -> replicator(both) -> ETF + ETR -> CATU(pass-through) */
    TRACE_MODE_FULL_INT  = 3   /* replicator(port0) -> ETF(SW FIFO, BUFWM=max) -> full IRQ after 1 word */
} trace_mode_t;

#endif /* CORESIGHT_TRACE_REGS_H */
