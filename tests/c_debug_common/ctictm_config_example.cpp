#include "drv_debug.h"

CPU_TEST_START
    OPEN_DEBUG_CRG();

    /* Enable local trigger input 0 and output 0 on CTM channel 0. */
    aon_cti_ctm_config(0U, 0x1U, 0x1U);

    /* Software-inject one pulse into CTM channel 0. */
    aon_cti_ctm_pulse(0U);

    c_uvm_info("aon_cti_ctm_pulse_case: chout=0x%x trout=0x%x",
               R32(AON_CTI_BASE + CTI_CH_OUT_STATUS),
               R32(AON_CTI_BASE + CTI_TRIG_OUT_STATUS));

    C_PASS();
CPU_TEST_END
