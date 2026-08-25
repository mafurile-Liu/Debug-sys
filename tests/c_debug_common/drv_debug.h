/*
 * drv_debug.h
 *
 * Header for the AON and dbg_ss (SYS) CoreSight trace-tree startup functions.
 *
 * drv_common.h (W32/R32, c_uvm_info/c_uvm_error, C_PASS, CPU_TEST_START/END,
 * OPEN_DEBUG_CRG) is assumed to be provided by the project environment and is
 * included here; this file does NOT redefine those.
 *
 * Function IMPLEMENTATIONS live in trace_config.c (this header is declarations
 * only). Register offsets are in coresight_trace_regs.h.
 *
 * Modes (trace_mode_t):
 *   TRACE_MODE_ETF_ONCHIP  - replicator(port0) -> ETF (circular buffer)
 *   TRACE_MODE_ETR_CATU    - replicator(port1) -> ETR -> CATU(translate) -> DRAM
 *   TRACE_MODE_CATU_BYPASS - replicator(both)  -> ETF + ETR -> CATU(pass-through)
 *   TRACE_MODE_FULL_INT    - replicator(port0) -> ETF(SW FIFO, BUFWM=MEM_SIZE-1)
 *                            full output asserts after 1 word -> full IRQ.
 *                            (ETR can also produce a full IRQ via the same
 *                            BUFWM mechanism in ETR mode; see TRM 9.16.12.)
 *
 * Replicator default (ARM SoC-600 TRM 9.9): IDFILT reset=0 = all IDs pass to
 * BOTH ports (broadcast). To disable a port write 0xFF.
 */

#ifndef DRV_DEBUG_H
#define DRV_DEBUG_H

#include <stdint.h>
#include "drv_common.h"
#include "coresight_trace_regs.h"

/* AON trace tree startup.
 * Trace sources (per AON_SS架构.png): M52 ITM, M52 ETM, HiFi5s TRAX/ITM
 * funnel_slave_port_mask: bit mask of FUNNEL slave ports to enable.
 * catu_sladdr: CATU scatter-list address (used in TRACE_MODE_ETR_CATU).
 *   Use CATU_SLADDR_DEFAULT (0x27400000) or override. 4KB-aligned. */
void aon_trace_init(trace_mode_t mode,
                    uint32_t     funnel_slave_port_mask,
                    uint32_t     etr_buf_addr,
                    uint32_t     etr_buf_size,
                    uint32_t     catu_sladdr);

/* dbg_ss (SYS) trace tree startup.
 * Trace source (per AON_SS架构.png): STM */
void dbg_ss_trace_init(trace_mode_t mode,
                       uint32_t     funnel_slave_port_mask,
                       uint32_t     etr_buf_addr,
                       uint32_t     etr_buf_size,
                       uint32_t     catu_sladdr);

#endif /* DRV_DEBUG_H */