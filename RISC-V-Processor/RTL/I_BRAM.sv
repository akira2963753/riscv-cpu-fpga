/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    I_BRAM.sv
* Project:      Five-Stage Pipelined RISC-V CPU
* Module:       I_BRAM
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
* Description:
*   Synchronous instruction memory initialized from a 32-bit readmemh image.
******************************************************************************/

`timescale 1ns/1ps
`include "SYSTEM_DEF.vh"

module I_BRAM (
    input logic clka,
    input logic ena,
    input logic [`BRAM_ADDR_W-1:0] addra,
    output logic [`INSTR_WIDTH-1:0] douta
);

    localparam string IM_FILE =
        "C:/Users/harry/Desktop/Project/risc-v/RISC-V-Processor/Testbench/IM.mem";

    logic [`INSTR_WIDTH-1:0] InstrMem [0:`BRAM_DEPTH-1];
    integer word_idx;

    initial begin
        for(word_idx = 0; word_idx < `BRAM_DEPTH; word_idx = word_idx + 1)
            InstrMem[word_idx] = `NOP;

        $readmemh(IM_FILE, InstrMem);
    end

    always_ff @(posedge clka) begin
        if(ena) douta <= InstrMem[addra];
    end

endmodule
