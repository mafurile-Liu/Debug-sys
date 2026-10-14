/*
 * c_config_m52_trace/main.cpp
 *
 * Minimal self-hosted M52 ITM/ETM trace case.
 *
 * This program runs on the M52 core and accesses the core's PPB registers
 * directly. It does not use <stdio.h>, the AHB-AP TAR/DRW debug path, or the
 * full trace_config helper, keeping the binary small.
 */

#include "drv_common.h"
#include "coresight_trace_regs.h"

/* M52 PPB registers (M52 TRM). */
#define M52_ITM_STIM(port)  (0xE0000000U + ((port) * 4U))
#define M52_ITM_TER         0xE0000E00U
#define M52_ITM_TCR         0xE0000E80U
#define M52_ITM_TCR_VAL     ((1U << 16) | (1U << 3) | 1U)
#define M52_ETM_BASE        0xE0041000U
#define M52_ETM_LAR         (M52_ETM_BASE + 0xFB0U)
#define M52_ETM_TRCPRGCTLR  (M52_ETM_BASE + 0x004U)
#define M52_ETM_TRCTRACEIDR (M52_ETM_BASE + 0x200U)
#define ETM_LAR_KEY         0xC5ACCE55U

CPU_TEST_START
    OPEN_DEBUG_CRG();

    /* Minimal AON trace sink: ETF HW FIFO -> ETR -> AON SRAM. */
    {
        uint32_t funnel_ctrl = R32(AON_FUNNEL_BASE + FUNNEL_CTRL);

        /* M52 ITM + M52 ETM funnel ports only. */
        funnel_ctrl &= ~FUNNEL_CTRL_RX_EN_MASK;
        funnel_ctrl |= 0x06U << FUNNEL_CTRL_RX_EN_SHIFT;
        W32(AON_FUNNEL_BASE + FUNNEL_CTRL, funnel_ctrl);

        W32(AON_REPLICATOR_BASE + REPL_IDFILTER0, REPL_IDFILTER_PASS_ALL);
        W32(AON_REPLICATOR_BASE + REPL_IDFILTER1, REPL_IDFILTER_PASS_ALL);

        W32(AON_ETF_BASE + TMC_MODE, TMC_MODE_HARDWARE_FIFO);
        W32(AON_ETF_BASE + TMC_BUFWM, 0U);
        W32(AON_ETF_BASE + TMC_RWP, 0U);
        W32(AON_ETF_BASE + TMC_RRP, 0U);
        W32(AON_ETF_BASE + TMC_FFCR, TMC_FFCR_ENTI | TMC_FFCR_ENFT);
        W32(AON_ETF_BASE + TMC_CTL, TMC_CTL_TRACECAPTEN);

        W32(AON_CATU_BASE + CATU_CONTROL, 0U);
        W32(AON_CATU_BASE + CATU_MODE, CATU_MODE_PASSTHROUGH);
        W32(AON_CATU_BASE + CATU_INADDRLO, AON_SRAM_BASE_ADDR);
        W32(AON_CATU_BASE + CATU_INADDRHI, 0U);
        W32(AON_CATU_BASE + CATU_CONTROL, CATU_CONTROL_EN);

        W32(AON_ETR_BASE + TMC_RSZ, 0x00004000U); /* 64KB in 32-bit words */
        W32(AON_ETR_BASE + TMC_MODE, TMC_MODE_CIRCULAR_BUFFER);
        W32(AON_ETR_BASE + TMC_DBALO, AON_SRAM_BASE_ADDR);
        W32(AON_ETR_BASE + TMC_DBAHI, 0U);
        W32(AON_ETR_BASE + TMC_AXICTL, TMC_AXICTL_DEFAULT);
        W32(AON_ETR_BASE + TMC_RWP, AON_SRAM_BASE_ADDR);
        W32(AON_ETR_BASE + TMC_RRPHI, 0U);
        W32(AON_ETR_BASE + TMC_RRP, AON_SRAM_BASE_ADDR);
        W32(AON_ETR_BASE + TMC_RWPHI, 0U);
        W32(AON_ETR_BASE + TMC_CTL, TMC_CTL_TRACECAPTEN);
    }

    /* Enable M52 debug trace logic. */
    W32(M52_DEMCR, M52_DEMCR_TRCENA);

    /* Enable all ITM stimulus ports and the ITM ATB interface. */
    W32(M52_ITM_TER, 0xFFFFFFFFU);
    W32(M52_ITM_TCR, M52_ITM_TCR_VAL);

    /* Unlock ETM, set trace ID, then enable the programmer. */
    W32(M52_ETM_LAR, ETM_LAR_KEY);
    W32(M52_ETM_TRCTRACEIDR, 0x00000002U);
    W32(M52_ETM_TRCPRGCTLR, 0x00000001U);

    /*
     * ITM only emits ATB data when software writes a stimulus port. Keep this
     * loop tiny; it also provides enough data to exercise downstream flushing.
     */
    for (unsigned int i = 0U; i < 16U; ++i) {
        W32(M52_ITM_STIM(0), 0xC0DE0000U + i);
    }

    c_uvm_info("%s", "m52 direct itm/etm trace enabled");
    C_PASS();
CPU_TEST_END
