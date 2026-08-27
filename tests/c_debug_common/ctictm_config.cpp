#include "drv_debug.h"
#include "drv_common.h"

/* ----------------------------------------------------------------------
 * Configure the AON CTI to observe a CTM channel.
 *
 * The physical CTI-to-CTM wiring is fixed. What software configures is:
 *   1. CTI enable.
 *   2. Which CTM channel is allowed through CTI_GATE.
 *   3. Which local CTI trigger outputs respond to that channel.
 *
 * input_mask selects local trigger inputs 0..8.
 * output_mask selects local trigger outputs 0..8.
 * Set a bit to map that local trigger to the selected CTM channel.
 * ---------------------------------------------------------------------- */
void aon_cti_ctm_config(uint32_t channel,
                         uint32_t input_mask,
                         uint32_t output_mask)
{
    uint32_t base = AON_CTI_BASE;
    uint32_t gate;
    uint32_t inen;
    uint32_t outen;
    uint32_t i;

    c_uvm_info("aon_cti_ctm_config: channel=%0d in_mask=0x%x out_mask=0x%x",
               channel, input_mask, output_mask);

    W32(base + CTI_CTR, CTI_CTR_EN);

    gate = R32(base + CTI_GATE);
    W32(base + CTI_GATE, gate | CTI_CHNL(channel));

    for (i = 0U; i < 9U; ++i) {
        if ((input_mask & (1U << i)) != 0U) {
            inen = R32(base + CTI_INEN(i));
            W32(base + CTI_INEN(i), inen | CTI_CHNL(channel));
        }

        if ((output_mask & (1U << i)) != 0U) {
            outen = R32(base + CTI_OUTEN(i));
            W32(base + CTI_OUTEN(i), outen | CTI_CHNL(channel));
        }
    }
}

void aon_cti_ctm_pulse(uint32_t channel)
{
    c_uvm_info("aon_cti_ctm_pulse: channel=%0d", channel);
    W32(AON_CTI_BASE + CTI_APPPULSE, CTI_CHNL(channel));
}
