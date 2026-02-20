// ============================================================================
// RISC-V Five-Stage Pipelined CPU - System Definitions
// Supports RV32I + RV32M Extension
// ============================================================================

`ifndef SYSTEM_DEF_VH
    `define SYSTEM_DEF_VH

    // ============================================================================
    // Memory Configuration
    // ============================================================================
    // Instruction Memory
    `define INSTR_WIDTH         32

    // Data Memory
    `define DATA_MEM_SIZE       32
    `define DATA_MEM_WIDTH      32
    `define DATA_MEM_ADDR_WIDTH 32

    // ============================================================================
    // Register File Configuration
    // ============================================================================
    `define GPR_SIZE    32          // 32 General Purpose Registers (x0-x31)
    `define PC_WIDTH    32
    `define DATA_WIDTH  32
    `define ADDR_WIDTH  5

    // ============================================================================
    // Immediate Generator Types
    // ============================================================================
    `define I_TYPE_IMM  0
    `define S_TYPE_IMM  1
    `define B_TYPE_IMM  2
    `define U_TYPE_IMM  3
    `define J_TYPE_IMM  4

    // ============================================================================
    // Instruction Opcodes
    // ============================================================================
    `define OPCODE_WIDTH    7

    // R-Type
    `define R_TYPE          7'b0110011

    // I-Type
    `define I_TYPE_ALU      7'b0010011
    `define I_TYPE_LOAD     7'b0000011
    `define I_TYPE_JALR     7'b1100111
    `define I_TYPE_CSR      7'b1110011

    // S-Type
    `define S_TYPE          7'b0100011

    // B-Type
    `define B_TYPE          7'b1100011

    // U-Type
    `define U_TYPE_LUI      7'b0110111
    `define U_TYPE_AUIPC    7'b0010111

    // J-Type
    `define J_TYPE_JAL      7'b1101111

    // ============================================================================
    // ALU Operation Types (used by Control Unit)
    // ============================================================================
    `define ALU_OP_ADD      2'b00
    `define ALU_OP_BRANCH   2'b01
    `define ALU_OP_R_TYPE   2'b10
    `define ALU_OP_I_TYPE   2'b11

    // ============================================================================
    // ALU Control Signals (5-bit)
    // ============================================================================
    // RV32I Base Instructions
    `define ALU_CTRL_ADD    5'b00000
    `define ALU_CTRL_SUB    5'b00001
    `define ALU_CTRL_SLL    5'b00010
    `define ALU_CTRL_SLT    5'b00011
    `define ALU_CTRL_SLTU   5'b00100
    `define ALU_CTRL_XOR    5'b00101
    `define ALU_CTRL_SRL    5'b00110
    `define ALU_CTRL_SRA    5'b00111
    `define ALU_CTRL_OR     5'b01000
    `define ALU_CTRL_AND    5'b01001

    // Branch Comparison Operations
    `define ALU_CTRL_GE     5'b01011
    `define ALU_CTRL_GEU    5'b01010

    // RV32M Extension (Multiply/Divide)
    `define ALU_CTRL_MUL    5'b01100   // Multiply (lower 32 bits)
    `define ALU_CTRL_MULH   5'b01111   // Multiply High (signed × signed)
    `define ALU_CTRL_MULHSU 5'b10000   // Multiply High (signed × unsigned)
    `define ALU_CTRL_MULHU  5'b10001   // Multiply High (unsigned × unsigned)
    `define ALU_CTRL_DIV    5'b01101   // Divide (signed)
    `define ALU_CTRL_DIVU   5'b10010   // Divide (unsigned)
    `define ALU_CTRL_REM    5'b01110   // Remainder (signed)
    `define ALU_CTRL_REMU   5'b10011   // Remainder (unsigned)

    // ============================================================================
    // Miscellaneous
    // ============================================================================
    `define NOP 32'h00000013

    // ============================================================================
    // Branch Prediction Unit (BPU) Configuration
    // ============================================================================
    `define BHT_PC_WIDTH    6
    `define BTB_PC_WIDTH    6
    `define BHT_SIZE        64
    `define BTB_SIZE        64

    // ============================================================================
    // Cache Configuration (optional)
    // ============================================================================
    `define WAY 2
    `define SET_NUM 64
    `define BLOCK_WORD_SIZE 8
    `define OFFSET_WIDTH 5
    `define WORD_OFFEST_WIDTH 3
    `define INDEX_WIDTH 6
    `define TAG_WIDTH 21


    `define DATA_W 32
    `define ADDR_W 32
    `define BRAM_DEPTH 1024
    `define BRAM_ADDR_W $clog2(`BRAM_DEPTH)

`endif // SYSTEM_DEF_VH
