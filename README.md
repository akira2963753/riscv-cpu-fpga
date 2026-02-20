# 32-bit RISC-V Processor on FPGA

A 32-bit pipelined RISC-V processor supporting **RV32I** and **RV32M** instruction sets, fully implemented and verified on FPGA.

This project originated from a [Computer Organization Course](https://github.com/akira2963753/5-Stage-Pipelined-MIPS-CPU) and [UC Berkeley CS 61C](https://cs61c.org/).  
For the complete architecture specification, see [`RISC-V-SPEC.pdf`](./RISC-V-SPEC.pdf).

---

## Features

| Category | Details |
|---|---|
| ISA | RV32I + RV32M (Base Integer + Multiply/Divide) |
| Pipeline | 5-stage: IF / ID / EX / MEM / WB |
| Hazard Handling | Data forwarding, load-use hazard stall, control hazard flush |
| Branch Prediction | Dynamic predictor with BHT (2-bit saturating counter) + BTB |
| Memory Hierarchy | 2-way set-associative I-Cache and D-Cache |
| Bus Interface | AXI4-Lite to BRAM (Instruction: BROM, Data: BRAM) |
| CSR | `mstatus`, `mtvec`, `mepc`, `mcause`, `rdcycle` |
| Target FPGA | Xilinx ZCU104 |
| EDA Tool | Vivado 2025.1 |

---

## Architecture Overview

### RISC-V Processor (with Cache)
<img width="1380" height="1188" alt="RISCV_ALL drawio (5)" src="https://github.com/user-attachments/assets/e1795da4-f3bf-4807-9f80-26bbf5fa83e0" />  

### Five-Stage Pipelined CPU Core (without Cache)
<img width="11724" height="5418" alt="RISC-V Processor (2)" src="https://github.com/user-attachments/assets/a04ef9c4-f134-427f-9750-519a973e3b93" />  

---

## Repository Structure

```
riscv-cpu-fpga/
├── Five-Stage-Pipelined-CPU/   # Core RTL: ALU, Register File, BPU, BHT, BTB, CSR, etc.
├── CACHE/                      # I-Cache and D-Cache with AXI4-Lite interface
├── RISC-V CPU CORE/            # Top-level processor integration
├── RISC-V-SPEC.pdf             # Full architecture specification
└── README.md
```

---

## Quick Start

### Prerequisites

- Xilinx Vivado 2025.1
- Python 3.x

### Run Simulation

**1. Select a test case and convert assembly to machine code:**

```bash
python Instr_Transfer.py
```

**2. Run automated verification (single test case or all):**

```bash
python Verify_Script.py
```

The script invokes Vivado simulation via TCL commands, compares the RTL output (`RF.out`, `DM.out`) against the Python golden model (`Golden_Result.py`), and reports pass/fail for each test case.

---

## Verification

Verification uses a custom Python behavioral model (`Golden_Result.py`) instead of the Spike ISA simulator, enabling faster iteration. The entire flow is fully automated via `Verify_Script.py`.

```
Assembly (.s)
    │
    ▼
Instr_Transfer.py ──► IM.dat ──► .coe (for BROM IP)
                                        │
                                        ▼
                              Vivado RTL Simulation
                              (driven by Script.tcl)
                                        │
                              RF.out + DM.out (RTL output)
                                        │
                                        ▼
                           Golden_Result.py (Python behavioral model)
                                        │
                           Verify_Script.py auto-compares ──► PASS / FAIL
```

Users can choose to run a single test case or all test cases at once:

```bash
python Verify_Script.py
```

12 test cases cover all RV32I and RV32M instructions, including arithmetic/logic, memory access (byte/half/word), branches, jumps, multiply/divide, and boundary conditions. **All 12 test cases pass.**

---

## Supported Instructions

**R-Type:** `ADD SUB SLL SLT SLTU XOR SRL SRA OR AND`  
**RV32M:** `MUL MULH MULHSU MULHU DIV DIVU REM REMU`  
**I-Type:** `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI JALR`  
**Load:** `LB LH LW LBU LHU`  
**Store:** `SB SH SW`  
**Branch:** `BEQ BNE BLT BGE BLTU BGEU`  
**Upper Immediate:** `LUI AUIPC`  
**Jump:** `JAL`  
**CSR:** `CSRRW CSRRS CSRRC`

---

## Future Work

- Upgrade D-Cache from write-through to write-back with a write buffer
- Add interrupt and exception handling
- Expand CSR support for full Machine-mode privilege

---

## License

This project is for educational purposes.
