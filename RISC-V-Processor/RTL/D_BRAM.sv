/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    D_BRAM.sv
* Project:      Five-Stage Pipelined RISC-V CPU
* Module:       D_BRAM
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
* Description:
*   Synchronous byte-write data memory used by the AXI4 data subordinate.
******************************************************************************/

`timescale 1ns/1ps
`include "SYSTEM_DEF.vh"

module D_BRAM (
    input logic clka,
    input logic ena,
    input logic [3:0] wea,
    input logic [`DATA_BRAM_ADDR_W-1:0] addra,
    input logic [`DATA_MEM_WIDTH-1:0] dina,
    output logic [`DATA_MEM_WIDTH-1:0] douta
);

    logic [31:0] DataMem [0:`DATA_BRAM_DEPTH-1];

    always_ff @(posedge clka) begin
        if(ena) begin
            if(wea[0]) DataMem[addra][7:0] <= dina[7:0];
            if(wea[1]) DataMem[addra][15:8] <= dina[15:8];
            if(wea[2]) DataMem[addra][23:16] <= dina[23:16];
            if(wea[3]) DataMem[addra][31:24] <= dina[31:24];

            if(wea == 4'b0000) douta <= DataMem[addra];
        end
    end

endmodule
