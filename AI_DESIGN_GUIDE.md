# AI Design Guide
## Debug SYS Standalone UVM Environment

Version: v1.0

---

# 1. Project Goal

This project is **NOT** a generic UVM example.

This project is the verification infrastructure for a future SoC Debug Subsystem.

The current stage has **NO DUT**.

The objective is to build a reusable verification environment that will later connect to the real RTL Debug Subsystem.

Code should always be written with future RTL integration in mind.

Never optimize only for the current standalone environment.

---

# 2. Verification Scope

Current verification targets:

- UVM infrastructure
- Agent interaction
- Register access flow
- Sequence framework
- Virtual sequence framework
- Predictor
- Scoreboard
- Coverage infrastructure

Future verification targets:

- Debug Subsystem RTL integration
- APB routing
- DAP routing
- Trace routing
- Interrupt routing
- Register connectivity
- Reset behavior
- Clock behavior

Assume ARM Debug IP is functionally correct.

Focus on SoC integration instead of ARM IP internal functionality.

---

# 3. Future Debug Architecture

Future architecture:

Debug Port
→ DAP
→ APB Decoder
→ {ETF, ETR, CTI, STM, ROM Table}

Trace path:

CPU ETM → ATB → Funnel → ETF / ETR

Reserve extension points for these modules.

---

# 4. Design Principles

- Reusable
- Configurable
- Replaceable
- Protocol independent
- DUT independent

Avoid writing code specifically for standalone mode.

---

# 5. Recommended UVM Architecture

```
debug_env
 ├── cfg
 ├── virtual_sequencer
 ├── register_model
 ├── predictor
 ├── scoreboard
 ├── coverage
 └── agents
      ├── JTAG
      ├── SWD
      ├── APB
      ├── AXI Monitor
      ├── ATB
      └── ClockReset
```

Future agents:

- CTI
- Interrupt
- Trace

---

# 6. Register Access Philosophy

Preferred flow:

Test

↓

Sequence

↓

RAL

↓

Bus Adapter

↓

APB / JTAG / SWD

Avoid direct APB transactions inside testcases whenever possible.

---

# 7. Predictor Philosophy

Predictor should model expected DUT behavior instead of forwarding transactions.

Future responsibilities:

- Address decode
- APB routing
- DAP routing
- Trace routing
- Interrupt routing
- Expected register state
- Expected protocol response

---

# 8. Scoreboard Philosophy

Compare **behavior**, not only transactions.

Future comparison targets:

- Register state
- Interrupt behavior
- Trace packets
- Routing correctness

---

# 9. Sequence Philosophy

Basic Sequence

↓

Protocol Sequence

↓

Feature Sequence

↓

Scenario Sequence

↓

Virtual Sequence

---

# 10. Address Map

Do not hardcode addresses.

Always use:

- Address Map
- Register Model

---

# 11. Configuration

Use configuration objects for all configurable features.

Examples:

- enable_jtag
- enable_swd
- enable_apb
- enable_atb
- enable_predictor
- enable_scoreboard

---

# 12. Coding Style

- Consistent naming
- Independent components
- Avoid duplicated logic
- Prefer extension over modification
- Leave hooks for future RTL

---

# 13. Current Status

- Standalone infrastructure
- No DUT
- No ARM RTL
- Focus on framework quality and reusability

---

# 14. Future Roadmap

Potential modules:

- DAP
- APB Decoder
- ROM Table
- ETF
- ETR
- Funnel
- STM
- CTI
- CTM
- APBIC
- SYS_DEBUG
