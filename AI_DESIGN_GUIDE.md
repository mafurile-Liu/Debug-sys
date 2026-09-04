# AI Design Guide - Debug SYS Verification Project (v2.0)

> AI-context document. Read this first to get up to speed on the project,
> its layout, verified hardware facts and conventions. Keep it current:
> whenever architecture, addresses or tooling change, update this file.

## 1. What this project is

Verification of the Debug Subsystem of an Arm-China-based SoC (project ZJ100).

- AON domain: M52 MCU (main controller), HiFi5s DSP, AON peripherals.
- System domains: A720 CPU clusters x6, NPU x6, GPU, ISP/VPU/DPU, DDR.
- Debug subsystem: CoreSight SoC-600-class - SWJ-DP + ADIv6 DAP + APBIC
  expanders + APB/AXI/APB trees + trace (funnel / ETF / ETR / CATU /
  replicator / CTI / CTM / STM / TPIU) + crash dump.

Two git repos with separate histories - never mix them:

| Repo | Remote | Content |
|------|--------|---------|
| Debug-sys (this repo) | github.com/mafurile-Liu/Debug-sys | Standalone SV/UVM environment; tests/c_debug_common (C trace/CTI driver library); architecture docs |
| openocd-sim-v0.2.0/ (nested, own .git) | github.com/mafurile-Liu/openocd-sim | OpenOCD-in-simulation framework + 47 TCL end-to-end debug test cases + C-side CPU tests |

The directories overlap on disk (openocd-sim lives inside this workspace)
but commits go to their own remotes.

## 2. Repository map

Debug-sys repo:
- README.md, README_ARCHITECTURE.md   - standalone UVM environment (VIP-to-VIP, no DUT yet)
- tb/                                 - UVM env: tb/env/{jtag,apb,atb,common}/, sequences
- tests/*.sv                          - UVM tests (smoke/entry/reg/trace/full)
- tests/c_debug_common/               - C/C++ trace + CTI driver library (see section 6)
- docs/SCOREBOARD_ROUTING.md          - scoreboard routing doc
- AI_DESIGN_GUIDE.md                  - THIS FILE
- untracked reference material (do not commit without asking):
  dbg_address_mapping.xlsx, soc_address_mapping_v0.1.xlsx,
  Project ZJ100 SYS AON.docx, Project_ZJ100_IP_crash_dump_HDD.docx,
  AON_SS architecture png, Debug_top_v0p7/ECT_v0p7 drawio pngs,
  xtensa_debug_guide.pdf, ARM IP debug TRMs on Desktop

openocd-sim-v0.2.0/ repo:
- src/                                - OpenOCD + DPI framework (do not touch casually)
- tests/ocd_debug_tests/              - 47 per-AP TCL cases (each dir: .tcl + filelist.f + test.cfg.mk + main.cpp)
- tests/bringup|dp_reg|apb_access|trace|full_debug/ - older layered TCL cases
- tests/ocd_common/addr_defs.tcl      - SINGLE SOURCE OF TRUTH for addresses/IDs
- tests/check_tcl.py                  - static checker for all TCL cases (run before push)
- tests/run_regression.sh             - batch regression
- tests/aon_crg_smoke_test/           - canonical CPU-side CRG clock-enable program (main.cpp)

## 3. Debug subsystem architecture (DUT view)

Two debug trees, both driven from one SWJ-DP + ADIv6 DAP:

DAP ROM table (m0, 0x4A000000) discovers 12 APs (m0..m11, base + 0x2000 step):
- m1 apb_ap_apbic     -> debug APB tree (exp0: AON comps @0x4A20_xxxx,
                         exp1: SYS comps @0x4A40_xxxx)
- m2 ahb_ap_m52       -> M52 AHB (AP.BASE 0xE00FF000 ROM table -> SCS)
- m3 axi_ap_aon_bus   -> AON bus (ITCM/DTCM/SRAM/DDR0)
- m4 jtag_ap_npu, m5 ahb_ap_gpu, m6..m11 axi_ap_npu0..5
- apb_tree_cpu (m19 view, 0x4B00_0000) -> 6x A720 cluster debug blocks

Trace topology (AON): sources (M52 ITM/ETM, HiFi5s TRAX on funnel port 3,
crash_dump on port 0) -> FUNNEL -> ETF -> REPLICATOR -> {ATB out, ETR -> CATU}.
ETF is IN SERIES in the trace path (not a parallel sink).
SYS tree: STM -> FUNNEL -> ETF/REPLICATOR -> {ETR->CATU, TPIU}.

Key addresses (full map in addr_defs.tcl / dbg_address_mapping.xlsx):
- ETF/ETR/REPLICATOR/CATU (AON): 0x4A203000/0x4A205000/0x4A204000/0x4A206000
- same set (SYS): 0x4A403000/0x4A405000/0x4A404000/0x4A406000, TPIU 0x4A407000
- STM (SYS): 0x4A400000; CTI (AON): 0x4A201000
- PERI_CTI_PMU_CPU: 0x4BF02000 (CPU APB tree CTI)
- M52 CPUID 0xE000ED00, DHCSR 0xE000EDF0 (ARMv8-M PPB, arch-fixed)

## 4. Verification stack (3 layers)

1. UVM standalone env (Debug-sys repo, tb/ + tests/*.sv):
   VIP-to-VIP closed loop (JTAG/SWD/APB/AXI/ATB), no DUT yet.
   See README.md and README_ARCHITECTURE.md.
2. OpenOCD e2e TCL cases (openocd-sim repo, tests/ocd_debug_tests/):
   Real OpenOCD drives the DUT DAP through remote_bitbang. 47 cases:
   ap0_romt_grp_scan, ap1_apb_ap (exp0/exp1 per-component), ap2_ahb_m52
   (m52_cpuid + m52_romtable_scan), ap3_axi_aon, ap4_jtag_npu,
   ap5_ahb_gpu, ap6_axi_npu, apb_tree_smoke (+ _swd), dap_ap_discovery.
   Pass = OpenOCD exit 0 AND "ALL CHECKS PASS" (checkpoint discipline).
3. C-side config library (Debug-sys repo, tests/c_debug_common/):
   CPU/cosim-side C++ drivers that configure CRG clocks, trace trees,
   CTI/CTM and HiFi TRAX. Examples per feature in *_example.cpp.

Flow: pick a mode -> aon_trace_init()/dbg_ss_trace_init() -> run trace
source -> observe AXI/APB/ATB waves -> read back via RRD if needed.

## 5. Trace driver API (tests/c_debug_common)

- aon_trace_init(mode, funnel_slave_port_mask, etr_buf_addr,
  etr_buf_size, catu_sladdr) - AON tree startup (see modes below)
- dbg_ss_trace_init(mode, funnel_mask, buf_addr, buf_size, catu_sladdr)
  - SYS tree startup (enables STM first)
- etr_scatter_list_build(sla, page_base, num_pages)
  - builds a CATU scatter list (identity-mapped 4KB pages, valid bits set,
    invalid terminator) - REQUIRED before translate mode
- tmc_etr_readback_start(base, rrp) - stop capture + set RRP; subsequent
  RRD APB reads issue AXI AR reads at RRP (trace read-back)
- crash_dump_start() - enable crash_dump funnel port
- aon_cti_ctm_config/pulse(channel, in_mask, out_mask) - CTI/CTM cross trigger
- hifi_trace_atb_start/stop/status(atid, smper, trace_ram) - HiFi5s TRAX

## 6. Trace modes (trace_mode_t, implemented in trace_config.cpp)

| Mode | ETF | ETR | CATU | Purpose |
|------|-----|-----|------|---------|
| 0 ETF_ONCHIP | circular buffer | - | - | on-chip capture, no reader needed |
| 1 ETF_ATB_ONLY | HW FIFO + FFCR forward | - | - | ETF passes trace to downstream ATB |
| 2 ETF_CATU_TRANSLATE | HW FIFO | CB, DBA=buf | translate + scatter list | DRAM/SRAM capture with VA->PA; issues AXI AR (walker) |
| 3 ETF_CATU_BYPASS | HW FIFO | CB, DBA=buf | pass-through | linear capture, no AR reads |
| 4 ETR_SWF1_FULL_INT | HW FIFO | SWF1 + BUFWM=RSZ-1 | - | full IRQ fires after 1st word |
| 5 CATU_ADDRERR | circular | CB | pass-through, INADDR = buf+1MB | ADDRERR IRQ on first ETR write |

## 7. Verified hardware facts and gotchas (TRM-backed)

Source docs: ARM 100806_0800_18 SoC-600 TRM (issue 18),
ARM DDI0528B (STM-500), IHI0029G (CoreSight v3). PDFs on Desktop "ARM IP/debug".

- TMC MODE encodings: 0=CB, 1=SWF1, 2=HWF, 3=SWF2. MODE=2 is Hardware FIFO,
  NOT "ETR mode". The ETR uses CB (MODE=0) with DBALO pointing at memory.
- ETR trace buffer lives in system memory at DBA; its size is
  SOFTWARE-programmed via RSZ (RSZ is RW for css600_tmc_etr, TRM 9.18.1).
  The ETB variant has RSZ = RO = MEM_SIZE (internal RAM) - do not confuse
  the variants. Wrap/full point = DBA + RSZ*4. Program RSZ only while
  TMCReady=1 and TraceCaptEn=0.
- There is no DBSIZE register. buf_size -> RSZ = buf_size/4 words.
- CB mode: RWP wrap sets STS.Full + drives buffer IRQ; capture keeps
  running and overwrites; Full clears only in Disabled state. Expected,
  not a bug (TRM 9.18.2 STS p837).
- SWF1: Full asserts when fill >= MEM_SIZE - BUFWM; BUFWM = RSZ-1 makes
  Full assert after the first word (fast interrupt test).
- ETF is IN SERIES in the trace path: funnel -> ETF -> replicator -> ETR.
  Configure ETF in every mode that routes trace to ETR.
- Replicator IDFILT0/1 (0x000/0x004): reset 0x00 = all IDs PASS (broadcast
  to both ports). To disable a port write 0xFF (per-ID-range bits). A
  single bit (1<<7) only discards IDs 0x70-0x7F - NOT the whole port.
- Funnel CTRL (css600_atbfunnel_prog): receiver enables ENS0-5 in
  bits[5:0] (bitmask, multiple ports OK), hold time [11:8],
  FLUSH_NORMAL bit12. Use read-modify-write.
- CATU: MODE 0=pass-through, 1=translate. Scatter list = 4KB-aligned table:
  bottom 2KB = 256 x 64-bit page entries (bit0=valid), top 2KB = next/prev
  linked-list addresses. One list covers 1MB of VA; VA[19:12] indexes
  pages, VA[X:20] selects the 1MB list. In pass-through mode the CATU
  issues NO AXI reads; in translate mode the walker fetches entries
  (AXI AR) at enable, on TLB miss and on prefetch. INADDRLO/HI = valid VA
  range lower bound; VA outside range -> STATUS.ADDRERR (IRQ via IRQEN).
  All CATU regs writable only while CONTROL.ENABLE=0 and STATUS.READY=1.
- ETR issues AXI READS too: trace read-back via RRD - program RRP then
  read RRD (APB); the TMC fetches the memory word with AXI AR at RRP
  (TRM 9.18.5). Valid in Disabled or CB/SWF1 modes. RRP advances one
  memory word (16B @ 128-bit ATB) per completed RRD read sequence.
- AXICTL (TMC): [3:0] WrBurstLen, 0=1 beat..15=16 beats. Program 0xF
  (TMC_AXICTL_DEFAULT). Burst bytes must fit the trace buffer size.
- CoreSight authentication (dbgen/spiden) MUST be high for the TMC to
  capture; tied to 0 the RAM is never written and ATB TX data reads X.
- tready_tx tied to 1'b0 blocks the ETF HW FIFO forward path (stalls
  once the internal buffer fills). Tie 1 or connect the real replicator.
- STM-500 register offsets: TCSR 0xE80, SYNCR 0xE90 (not 0x000/0x00C).
- TPIU SPPR = 0x0F0 (0x300 is FFSR); FFCR FlushMan = bit6.
- HiFi5s is a Cadence Xtensa DSP: trace = TRAX (TRAXCTRL 0x004:
  ATEN bit31, ATID[30:24], TMEN bit7, TREN bit0; TRAXSTAT 0x008 TRACT
  bit0). ATB output feeds AON funnel slave port 3.
- M52 CPU = Arm China Cortex-M52 (NOT Arm Ltd). CPUID reads 0x630FD244:
  IMPLEMENTER 0x63 (Arm China), ARCH 0xF (ARMv8-M), PARTNO 0xD24, r0p4.
  Stored in addr_defs.tcl as M52_CPUID_VAL; m52_cpuid case checks it exactly.
- M52 ROM table at 0xE00FF000 (AP2 AP.BASE, xlsx m2). ROM table entries
  are SIGNED offsets - SCS at 0xE000E000 sits BELOW the ROM table base;
  that is the standard ARM Cortex-M PPB layout, not an address bug.
- DAP IDs: SWD DPIDR 0x6C013477, JTAG IDCODE 0x6BA06477 (SoC-600 css600_dp).
- Jim Tcl gotchas: no BOM, ASCII only, no CRLF; format %X needs integer
  vars (use scan, not expr, for hex strings - fixed in addr_defs.tcl).
- APB tree _swd vs JTAG variants: same test body, only the init proc
  differs (dap_init_swd vs dap_init_jtag). SWD uses the same SWJ-DP.

## 8. Sim-observed behaviour log (confirmed in waves)

- ETR HW config: MEM_SIZE=4 words is NOT the case - ETR RSZ is RW (see
  above); with RSZ programmed to 64KB the CB wrap/full point moves to
  DBA+64KB and 16-beat bursts become reachable.
- One 128-bit ATB write with RSZ unprogrammed (reset 4 words = 16B)
  filled the whole CB -> immediate Full; WrBurstLen=15 is then
  incompatible (burst bytes > buffer) -> AxLEN=0. Root cause was the
  unprogrammed RSZ, not the AXICTL setting.
- ETF APB write sequence observed in waves matches tmc_etf_hw_fifo_config
  exactly: MODE(0x28)=2, BUFWM(0x34)=0, RWP(0x18)=0, RRP(0x14)=0,
  FFCR(0x304)=3, CTL(0x20)=1.
- M52 CPUID readback = 0x630FD244 on live silicon sim (after clocks were
  enabled); CPUID=0 means clk_m52/reset problem, not a spec value.

## 9. Conventions

- addr_defs.tcl is the single source of truth for addresses/IDs; TCL cases
  never hardcode addresses. Expected values come from spec documents, not
  from RTL reverse-engineering.
- TCL files: ASCII only, LF only, no BOM, checkpoint_report last. Run
  tests/check_tcl.py before pushing.
- C/C++ sources in c_debug_common: LF only (enforced by .gitattributes,
  CRLF shows as ^M on the Linux TOT side). drv_common.h/drv_debug.h
  macros (W32/R32, c_uvm_info, C_PASS, CPU_TEST_START/END,
  OPEN_DEBUG_CRG) are provided by the project env on the TOT side.
- openocd-sim and Debug-sys are separate repos; never cross-commit.
- Reference xlsx/docx/pdf design docs in the workspace root are untracked
  on purpose - ask before committing them.
- Every code change: show the diff to the user, then push (default, no
  confirmation needed).