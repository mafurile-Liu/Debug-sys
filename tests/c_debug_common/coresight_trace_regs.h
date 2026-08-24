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
 * Register offsets are taken from ARM official documents where explicitly noted.
 * Any offset marked "PROJECT_VERIFY" must be checked against the actual RTL
 * or implementation register spec before use.
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
 * IMPORTANT: offsets below are from the existing project test
 *   openocd-sim-v0.2.0/tests/trace/etr_config_check.tcl
 * and are marked PROJECT_VERIFY because this SoC might integrate a
 * different TMC version than the standard SoC-600 css600_tmc.
 * ====================================================================== */
#define TMC_RSZ                0x000U  /* PROJECT_VERIFY */
#define TMC_STS                0x004U  /* PROJECT_VERIFY */
#define TMC_MODE               0x01CU  /* from project etr_config_check.tcl */
#define TMC_LBUFLEVEL          0x024U  /* PROJECT_VERIFY */
#define TMC_CBSIZE             0x028U  /* PROJECT_VERIFY */
#define TMC_AXICTRL            0x02CU  /* PROJECT_VERIFY */
#define TMC_DBALO              0x03CU  /* from project etr_config_check.tcl */
#define TMC_DBAHI              0x040U  /* from project etr_config_check.tcl */
#define TMC_DBSIZE             0x050U  /* from project etr_config_check.tcl */

#define TMC_MODE_HW_FIFO       0x00000000U
#define TMC_MODE_SW_FIFO       0x00000001U
#define TMC_MODE_ETR           0x00000002U

/* ======================================================================
 * CoreSight Replicator
 * Source: ARM IHI0029G + ARM 100806_0800_18 SoC-600 TRM
 * ====================================================================== */
#define REPL_IDFILTER0         0x000U
#define REPL_IDFILTER1         0x004U
#define REPL_IDFILTER_DISABLE  (1U << 7)

/* ======================================================================
 * CoreSight TPIU
 * Source: ARM 100806_0800_18 SoC-600 TRM
 * ====================================================================== */
#define TPIU_SSPSR             0x000U  /* PROJECT_VERIFY */
#define TPIU_CSPSR             0x004U  /* PROJECT_VERIFY */
#define TPIU_ACPR              0x010U  /* PROJECT_VERIFY */
#define TPIU_SPPR              0x300U  /* PROJECT_VERIFY */
#define TPIU_FFCR              0x304U  /* PROJECT_VERIFY */

#define TPIU_SPPR_PARALLEL     0x00000000U
#define TPIU_SPPR_SWO_NRZ      0x00000001U
#define TPIU_SPPR_SWO_MANCHESTER 0x00000002U

#define TPIU_FFCR_ENFCONT      (1U << 1)
#define TPIU_FFCR_FLUSHMAN     (1U << 12)

/* ======================================================================
 * CoreSight STM-500 (System Trace Macrocell)
 * Source: ARM DDI0528B
 * ====================================================================== */
#define STM_TCSR               0x000U
#define STM_SYNCR              0x00CU

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
#define CATU_MODE_TRANSLATE    0x00000001U

/* ======================================================================
 * Trace startup mode selectors
 * ====================================================================== */
typedef enum {
    TRACE_MODE_ETF_ONCHIP = 0,   /* source -> funnel -> ETF (on-chip FIFO) */
    TRACE_MODE_ETR_CATU   = 1,   /* source -> funnel -> replicator -> ETR -> CATU -> DRAM */
    TRACE_MODE_TPIU_OFFCHIP = 2  /* source -> funnel -> replicator -> TPIU (off-chip) */
} trace_mode_t;

#endif /* CORESIGHT_TRACE_REGS_H */