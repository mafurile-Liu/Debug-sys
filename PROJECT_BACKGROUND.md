# Debug SYS Project Background

## Project

SoC Debug Subsystem Verification

## Current Stage

- Standalone UVM Environment
- No DUT
- Framework construction

## Final Goal

Connect ARM CoreSight Debug Subsystem RTL and perform SoC integration verification.

## Verification Strategy

ARM Debug IP is treated as **Golden**.

Focus on:

- Integration verification
- Register connectivity
- Trace path
- APB routing
- DAP routing
- Interrupt routing
- Clock & Reset

Do **NOT** verify ARM internal implementation.

## Project Constraints

- Design for future RTL integration.
- Avoid temporary solutions.
- Prefer reusable architecture.
- Separate protocol from testcase logic.
- Use RAL as the primary register access mechanism.

## Long-term Objective

Build a production-quality reusable Debug verification framework instead of a demo environment.
