/*
 * drv_debug.h
 *
 * Header for the AON and dbg_ss (SYS) CoreSight trace-tree startup functions.
 *
 * drv_common.h (W32/R32, c_uvm_info/c_uvm_error, C_PASS, CPU_TEST_START/END,
 * OPEN_DEBUG_CRG) is assumed to be provided by the project environment and is
 * included here; this file does NOT redefine those.
 *
 * Function IMPLEMENTATIONS live in trace_config.cpp (this header is declarations
 * only). Register offsets are in coresight_trace_regs.h.
 *
 * Modes (trace_mode_t):
 *   TRACE_MODE_ETF_ONCHIP    - replicator(port0) -> ETF (circular buffer)
 *   TRACE_MODE_ETF_ATB_ONLY      - replicator(port0) -> ETF -> ATB only
 *   TRACE_MODE_ETF_CATU_TRANSLATE - replicator(both) -> ETF -> ATB + ETR -> CATU(translate)
 *   TRACE_MODE_ETF_CATU_BYPASS    - replicator(both) -> ETF -> ATB + ETR -> CATU(bypass)
 *   TRACE_MODE_ETR_SWF1_FULL_INT - ETF -> replicator -> ATB + ETR(SWF1, BUFWM=max) -> full IRQ
 *   TRACE_MODE_CATU_ADDRERR - replicator(port1) -> ETR -> CATU(INADDR wrong) -> ADDRERR IRQ
 *
 * Replicator default (ARM SoC-600 TRM 9.9): IDFILT reset=0 = all IDs pass to
 * BOTH ports (broadcast). To disable a port write 0xFF.
 *
 * CATU INADDR (TRM 9.12.7/9.12.8): validates the ETR write address in BOTH
 * translate and pass-through modes. VA out of range -> STATUS.ADDRERR -> IRQ.
 * ADDRERR mode deliberately sets INADDR above the buffer to trigger it.
 */

#ifndef DRV_DEBUG_H
#define DRV_DEBUG_H

#include <stdint.h>
#include "drv_common.h"
#include "coresight_trace_regs.h"

/* AON trace tree startup.
 * Trace sources (per AON_SS架构.png): M52 ITM, M52 ETM, HiFi5s TRAX/ITM
 * funnel_slave_port_mask: bit mask of FUNNEL slave ports to enable.
 * catu_sladdr: CATU scatter-list address (used in TRACE_MODE_ETF_CATU_TRANSLATE).
 *   Use CATU_SLADDR_DEFAULT (AON SRAM base + 0x10000) or override. 4KB-aligned.
 * etr_buf_size: ETR trace-buffer size in bytes - programmed into RSZ (RW for
 *   the css600_tmc_etr variant, TRM 9.18.1). Must be a multiple of the AXI
 *   data width (16B @ 128-bit), >= 512B for SW FIFO modes, >= 16B (1 AXI
 *   dataword) for CB mode. Defines the CB wrap point [DBA, DBA+RSZ*4). */
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

void OPEN_DEBUG_CRG();

/* Enable crash_dump as an AON trace source. */
void crash_dump_start(void);

/* Build a CATU scatter list (identity-mapped 4KB pages) in system memory.
 * Must be called before enabling the CATU in translate mode; the CATU
 * fetches this list via AXI AR reads (walker init + TLB miss/prefetch). */
void etr_scatter_list_build(uint32_t sla, uint32_t page_base, uint32_t num_pages);

/* Stop ETR capture and set RRP: subsequent RRD APB reads issue AXI AR
 * accesses at RRP (trace read-back path, TRM 9.18.5). */
void tmc_etr_readback_start(uint32_t base, uint32_t rrp_addr);

/* Configure AON CTI inputs/outputs on a CTM channel. */
void aon_cti_ctm_config(uint32_t channel,
                       uint32_t input_mask,
                       uint32_t output_mask);

/* Software-pulse a CTM channel through CTI APPPULSE. */
void aon_cti_ctm_pulse(uint32_t channel);

/* Start HiFi5s TRAX trace output on ATB. */
void hifi_trace_atb_start(uint8_t atid,
                          uint8_t smper,
                          bool enable_trace_ram);

/* Stop HiFi5s TRAX trace output. */
void hifi_trace_atb_stop(void);

/* Read HiFi5s TRAX status. */
uint32_t hifi_trace_atb_status(void);

#endif /* DRV_DEBUG_H */
