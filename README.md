# RISC-V Pipelined CPU on FPGA

A 32-bit pipelined RISC-V processor supporting **RV32I** and **RV32M** instruction sets, implemented and verified on FPGA.

This project originates from a [Computer Organization course](https://github.com/akira2963753/mips-5stage-cpu) and [UC Berkeley CS 61C](https://cs61c.org/).

---

## Features

- 5-stage pipeline: IF / ID / EX / MEM / WB
- Data forwarding and hazard detection
- Flush detection for control hazards
- Dynamic branch predictor
- Instruction and data cache
- AXI4-Lite bus interface to BRAM

## Repository Structure

| Directory | Description |
|---|---|
| `Five-Stage-Pipelined-CPU/` | Core RTL modules (ALU, register file, control logic, etc.) |
| `CACHE/` | L1 instruction / data cache with AXI4-Lite interface |
| `RISC-V-Processor` | Top-level processor integration |

## Documentation

Detailed architecture specification: [`RISC-V-SPEC.pdf`](./RISC-V-SPEC.pdf)

## Tools

- Simulation: Xilinx Vivado
- Synthesis & Implementation: Xilinx Vivado
- Target: Xilinx FPGA
