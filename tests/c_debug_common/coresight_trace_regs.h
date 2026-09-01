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
#define AON_CRASH_DUMP_BASE  0x4A207000U

/* AON crash_dump is a trace source into AON_FUNNEL slave port 0. */
#define AON_CRASH_DUMP_FUNNEL_SLAVE_PORT 0U

/* HiFi5s debug/TRAX APB base and AON trace-tree slave port. */
#define HIFI_TRAX_BASE       0x4A240000U
#define HIFI_TRACE_FUNNEL_SLAVE_PORT 3U

/* Xtensa TRAX register offsets. */
#define HIFI_TRAXCTRL        0x0004U
#define HIFI_TRAXSTAT        0x0008U
#define HIFI_TRAXADDR        0x0010U

/* TRAXCTRL bit fields. */
#define TRAXCTRL_ATEN        (1U << 31)
#define TRAXCTRL_ATID_SHIFT  24
#define TRAXCTRL_ATID_MASK   0x7FU
#define TRAXCTRL_SMPER_SHIFT 12
#define TRAXCTRL_SMPER_MASK  0x07U
#define TRAXCTRL_TMEN        (1U << 7)
#define TRAXCTRL_TREN        (1U << 0)
#define TRAXCTRL_TRSTP       (1U << 1)

/* TRAXSTAT bit fields. */
#define TRAXSTAT_TRACT       (1U << 0)

/* SYS / dbg_ss trace tree (APBIC_SYS_DBG expander1)
 * Trace source (per AON_SS架构.png): STM */
#define SYS_STM_BASE         0x4A400000U
#define SYS_FUNNEL_BASE      0x4A402000U
#define SYS_ETF_BASE         0x4A403000U
#define SYS_REPLICATOR_BASE  0x4A404000U
#define SYS_ETR_BASE         0x4A405000U
#define SYS_CATU_BASE        0x4A406000U
#define SYS_TPIU_BASE        0x4A407000U

/* M52-specific crash dump aperture. */
#define M52_CRASH_DUMP_BASE  0x4A300000U

/* AON system SRAM base used as the ETR trace buffer. */
#define AON_SRAM_BASE_ADDR   0x27400000U

/* ======================================================================
 * CoreSight SoC-600 css600_atbfunnel_prog
 * Source: ARM 100806_0800_18 SoC-600 TRM, section 9.8.1.
 * FUNNELCONTROL[7:0] contains ENS0-ENS7, one receiver-enable bit per port.
 * [11:8] is HT and [12] is FLUSH_NORMAL.
 * ====================================================================== */
#define FUNNEL_CTRL            0x000U
#define FUNNEL_PRIORITYCONTROL 0x004U

#define FUNNEL_CTRL_ENS0       (1U << 0)
#define FUNNEL_CTRL_RX_EN_SHIFT     0
#define FUNNEL_CTRL_RX_EN_MASK     0x3FU
#define FUNNEL_CTRL_HT_SHIFT        8
#define FUNNEL_CTRL_FLUSH_NORMAL   (1U << 12)

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
#define TMC_FFCR                0x304U  /* ARM SoC-600 css600_tmc_etf: Formatter and Flush Control Register */
#define TMC_RRP                 0x014U  /* RAM Read Pointer */
#define TMC_RWP                 0x018U  /* RAM Write Pointer */
#define TMC_RRPHI               0x038U  /* RAM Read Pointer High */
#define TMC_RWPHI               0x03cU  /* RAM Write Pointer High */
#define TMC_CTL_TRACECAPTEN     (1U << 0)  /* CTL bit0: set to START trace capture (TRM 4.8.5 step 8) */
#define TMC_AXICTL_DEFAULT      0x00000000U  /* placeholder; program per SoC AXI integration (burst/AxCACHE/AxPROT) */

#define TMC_MODE_CIRCULAR_BUFFER 0x00000000U
#define TMC_MODE_SOFTWARE_FIFO_1 0x00000001U
#define TMC_MODE_HARDWARE_FIFO   0x00000002U
#define TMC_MODE_SOFTWARE_FIFO_2 0x00000003U

#define TMC_FFCR_ENTI          (1U << 1)
#define TMC_FFCR_ENFT          (1U << 0)

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
#define CATU_SLADDR_DEFAULT  (AON_SRAM_BASE_ADDR + 0x00010000U) /* default CATU scatter-list address */
#define CATU_MODE_TRANSLATE    0x00000001U

/* ======================================================================
 * Trace startup mode selectors
 * ====================================================================== */
typedef enum {
    TRACE_MODE_ETF_ONCHIP = 0,   /* source -> funnel -> ETF (circular buffer) */
    TRACE_MODE_ETF_ATB_ONLY = 1, /* source -> funnel -> ETF -> ATB only */
    TRACE_MODE_ETF_CATU_TRANSLATE = 2, /* source -> funnel -> ETF -> replicator -> ATB + ETR -> CATU */
    TRACE_MODE_ETF_CATU_BYPASS = 3, /* source -> funnel -> ETF -> replicator -> ATB + ETR -> CATU */
    TRACE_MODE_ETR_SWF1_FULL_INT = 4, /* ETF -> replicator -> ATB + ETR(SWF1, BUFWM=max) -> full IRQ */
    TRACE_MODE_CATU_ADDRERR = 5  /* CATU INADDR deliberately wrong -> ETR write triggers ADDRERR IRQ */
} trace_mode_t;

/* ======================================================================
 * CoreSight CTI / CTM
 * ====================================================================== */
#define AON_CTI_BASE         0x4A201000U

#define CTI_CONTROL            0x000U
#define CTI_TRIGGER_COUNT       32U
#define CTI_INTACK              0x010U
#define CTI_APP_SET             0x014U
#define CTI_APP_CLEAR           0x018U
#define CTI_APP_PULSE           0x01CU
#define CTI_TRIG_IN_STATUS      0x130U
#define CTI_TRIG_OUT_STATUS     0x134U
#define CTI_CH_IN_STATUS        0x138U
#define CTI_CH_OUT_STATUS       0x13CU
#define CTI_GATE                0x140U
#define CTI_ASICCTRL            0x144U

#define CTI_CONTROL_EN          (1U << 0)
#define CTI_CHNL(x)             (1U << (x))
#define CTI_INEN(n)             (0x020U + (4U * (n)))
#define CTI_OUTEN(n)            (0x0A0U + (4U * (n)))

#endif /* CORESIGHT_TRACE_REGS_H */
