# RISC-V Pipelined CPU on FPGA

A 32-bit pipelined RISC-V processor supporting **RV32I** and **RV32M** instruction sets, implemented and verified on FPGA.

This project originates from a Computer Organization course and [UC Berkeley CS 61C](https://cs61c.org/).

---

## Features

- 5-stage pipeline: IF / ID / EX / MEM / WB
- Data forwarding and hazard detection
- Flush detection for control hazards
- Dynamic branch predictor
- Instruction and data L1 cache
- AXI4-Lite bus interface to BRAM

## Repository Structure

| Directory | Description |
|---|---|
| `RISC-V CPU CORE/` | Core RTL modules (ALU, register file, control logic, etc.) |
| `Five-Stage-Pipelined-CPU/` | Top-level pipeline integration |
| `CACHE/` | L1 instruction / data cache with AXI4-Lite interface |

## Languages

- Verilog — RTL design (65.9%)
- Python — simulation / verification scripts (30.6%)
- SystemVerilog — testbenches (3.5%)

## Documentation

Detailed architecture specification: [`RISC-V-SPEC.pdf`](./RISC-V-SPEC.pdf)

## Tools

- Simulation: Icarus Verilog / ModelSim
- Synthesis & Implementation: Xilinx Vivado
- Target: Xilinx FPGA
