/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    RISCV_PROCESSOR.sv
* Project:      Five-Stage Pipelined RISC-V CPU
* Module:       RISCV_PROCESSOR
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
* Description:
*   Processor integration top with independent AXI4 instruction and data
*   paths. The instruction path is read-only; the data path supports reads
*   and write-through stores.
******************************************************************************/

`timescale 1ns/1ps
`include "SYSTEM_DEF.vh"

module RISCV_PROCESSOR (
    input logic ACLK,
    input logic ARESETn,
    output logic [`PC_WIDTH-1:0] PC_OUT
);

    //=============================================================
    // ---------------- Instruction AXI4 Signals ------------------
    //=============================================================
    logic [`AXI_ID_W-1:0] I_AW_ID;
    logic [`ADDR_W-1:0] I_AW_ADDR;
    logic [7:0] I_AW_LEN;
    logic [2:0] I_AW_SIZE;
    logic [1:0] I_AW_BURST;
    logic I_AW_LOCK;
    logic [3:0] I_AW_CACHE;
    logic [2:0] I_AW_PROT;
    logic [3:0] I_AW_QOS;
    logic I_AW_VALID;
    logic I_AW_READY;
    logic [`DATA_W-1:0] I_W_DATA;
    logic [`DATA_W/8-1:0] I_W_STRB;
    logic I_W_LAST;
    logic I_W_VALID;
    logic I_W_READY;
    logic [`AXI_ID_W-1:0] I_B_ID;
    logic [1:0] I_B_RESP;
    logic I_B_VALID;
    logic I_B_READY;

    logic [`AXI_ID_W-1:0] I_AR_ID;
    logic [`ADDR_W-1:0] I_AR_ADDR;
    logic [7:0] I_AR_LEN;
    logic [2:0] I_AR_SIZE;
    logic [1:0] I_AR_BURST;
    logic I_AR_LOCK;
    logic [3:0] I_AR_CACHE;
    logic [2:0] I_AR_PROT;
    logic [3:0] I_AR_QOS;
    logic I_AR_VALID;
    logic I_AR_READY;
    logic [`AXI_ID_W-1:0] I_R_ID;
    logic [`DATA_W-1:0] I_R_DATA;
    logic [1:0] I_R_RESP;
    logic I_R_LAST;
    logic I_R_VALID;
    logic I_R_READY;

    logic I_BRAM_EN;
    logic [`DATA_W/8-1:0] I_BRAM_WE;
    logic [`BRAM_ADDR_W-1:0] I_BRAM_ADDR;
    logic [`DATA_W-1:0] I_BRAM_DIN;
    logic [`DATA_W-1:0] I_BRAM_DOUT;

    //=============================================================
    // -------------------- Data AXI4 Signals ---------------------
    //=============================================================
    logic [`AXI_ID_W-1:0] D_AW_ID;
    logic [`ADDR_W-1:0] D_AW_ADDR;
    logic [7:0] D_AW_LEN;
    logic [2:0] D_AW_SIZE;
    logic [1:0] D_AW_BURST;
    logic D_AW_LOCK;
    logic [3:0] D_AW_CACHE;
    logic [2:0] D_AW_PROT;
    logic [3:0] D_AW_QOS;
    logic D_AW_VALID;
    logic D_AW_READY;
    logic [`DATA_W-1:0] D_W_DATA;
    logic [`DATA_W/8-1:0] D_W_STRB;
    logic D_W_LAST;
    logic D_W_VALID;
    logic D_W_READY;
    logic [`AXI_ID_W-1:0] D_B_ID;
    logic [1:0] D_B_RESP;
    logic D_B_VALID;
    logic D_B_READY;

    logic [`AXI_ID_W-1:0] D_AR_ID;
    logic [`ADDR_W-1:0] D_AR_ADDR;
    logic [7:0] D_AR_LEN;
    logic [2:0] D_AR_SIZE;
    logic [1:0] D_AR_BURST;
    logic D_AR_LOCK;
    logic [3:0] D_AR_CACHE;
    logic [2:0] D_AR_PROT;
    logic [3:0] D_AR_QOS;
    logic D_AR_VALID;
    logic D_AR_READY;
    logic [`AXI_ID_W-1:0] D_R_ID;
    logic [`DATA_W-1:0] D_R_DATA;
    logic [1:0] D_R_RESP;
    logic D_R_LAST;
    logic D_R_VALID;
    logic D_R_READY;

    logic D_BRAM_EN;
    logic [`DATA_W/8-1:0] D_BRAM_WE;
    logic [`DATA_BRAM_ADDR_W-1:0] D_BRAM_ADDR;
    logic [`DATA_W-1:0] D_BRAM_DIN;
    logic [`DATA_W-1:0] D_BRAM_DOUT;

    //=============================================================
    // ------------------ Instruction Memory ---------------------
    //=============================================================
    I_BRAM Instruction_Mem (
        .clka(ACLK),
        .ena(I_BRAM_EN),
        .addra(I_BRAM_ADDR),
        .douta(I_BRAM_DOUT)
    );

    //=============================================================
    // ---------------- Instruction AXI4 Bus ---------------------
    //=============================================================
    assign I_AW_ID = '0;
    assign I_AW_ADDR = '0;
    assign I_AW_LEN = '0;
    assign I_AW_SIZE = '0;
    assign I_AW_BURST = '0;
    assign I_AW_LOCK = 1'b0;
    assign I_AW_CACHE = '0;
    assign I_AW_PROT = '0;
    assign I_AW_QOS = '0;
    assign I_AW_VALID = 1'b0;
    assign I_W_DATA = '0;
    assign I_W_STRB = '0;
    assign I_W_LAST = 1'b0;
    assign I_W_VALID = 1'b0;
    assign I_B_READY = 1'b0;

    AXI4_Bus #(
        .DATA_W(`DATA_W),
        .ADDR_W(`ADDR_W),
        .ID_W(`AXI_ID_W),
        .BRAM_DEPTH(`BRAM_DEPTH),
        .BRAM_ADDR_W(`BRAM_ADDR_W)
    ) Instruction_AXI4_Bus (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AW_ID(I_AW_ID),
        .AW_ADDR(I_AW_ADDR),
        .AW_LEN(I_AW_LEN),
        .AW_SIZE(I_AW_SIZE),
        .AW_BURST(I_AW_BURST),
        .AW_LOCK(I_AW_LOCK),
        .AW_CACHE(I_AW_CACHE),
        .AW_PROT(I_AW_PROT),
        .AW_QOS(I_AW_QOS),
        .AW_VALID(I_AW_VALID),
        .AW_READY(I_AW_READY),
        .W_DATA(I_W_DATA),
        .W_STRB(I_W_STRB),
        .W_LAST(I_W_LAST),
        .W_VALID(I_W_VALID),
        .W_READY(I_W_READY),
        .B_ID(I_B_ID),
        .B_RESP(I_B_RESP),
        .B_VALID(I_B_VALID),
        .B_READY(I_B_READY),
        .AR_ID(I_AR_ID),
        .AR_ADDR(I_AR_ADDR),
        .AR_LEN(I_AR_LEN),
        .AR_SIZE(I_AR_SIZE),
        .AR_BURST(I_AR_BURST),
        .AR_LOCK(I_AR_LOCK),
        .AR_CACHE(I_AR_CACHE),
        .AR_PROT(I_AR_PROT),
        .AR_QOS(I_AR_QOS),
        .AR_VALID(I_AR_VALID),
        .AR_READY(I_AR_READY),
        .R_ID(I_R_ID),
        .R_DATA(I_R_DATA),
        .R_RESP(I_R_RESP),
        .R_LAST(I_R_LAST),
        .R_VALID(I_R_VALID),
        .R_READY(I_R_READY),
        .BRAM_EN(I_BRAM_EN),
        .BRAM_WE(I_BRAM_WE),
        .BRAM_ADDR(I_BRAM_ADDR),
        .BRAM_DIN(I_BRAM_DIN),
        .BRAM_DOUT(I_BRAM_DOUT)
    );

    //=============================================================
    // --------------------- RISC-V CPU Core ----------------------
    //=============================================================
    RISCV_CPU RISC_V_CPU_inst (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .I_AR_ID(I_AR_ID),
        .I_AR_ADDR(I_AR_ADDR),
        .I_AR_LEN(I_AR_LEN),
        .I_AR_SIZE(I_AR_SIZE),
        .I_AR_BURST(I_AR_BURST),
        .I_AR_LOCK(I_AR_LOCK),
        .I_AR_CACHE(I_AR_CACHE),
        .I_AR_PROT(I_AR_PROT),
        .I_AR_QOS(I_AR_QOS),
        .I_AR_VALID(I_AR_VALID),
        .I_AR_READY(I_AR_READY),
        .I_R_ID(I_R_ID),
        .I_R_DATA(I_R_DATA),
        .I_R_RESP(I_R_RESP),
        .I_R_LAST(I_R_LAST),
        .I_R_VALID(I_R_VALID),
        .I_R_READY(I_R_READY),
        .D_AW_ID(D_AW_ID),
        .D_AW_ADDR(D_AW_ADDR),
        .D_AW_LEN(D_AW_LEN),
        .D_AW_SIZE(D_AW_SIZE),
        .D_AW_BURST(D_AW_BURST),
        .D_AW_LOCK(D_AW_LOCK),
        .D_AW_CACHE(D_AW_CACHE),
        .D_AW_PROT(D_AW_PROT),
        .D_AW_QOS(D_AW_QOS),
        .D_AW_VALID(D_AW_VALID),
        .D_AW_READY(D_AW_READY),
        .D_W_DATA(D_W_DATA),
        .D_W_STRB(D_W_STRB),
        .D_W_LAST(D_W_LAST),
        .D_W_VALID(D_W_VALID),
        .D_W_READY(D_W_READY),
        .D_B_ID(D_B_ID),
        .D_B_RESP(D_B_RESP),
        .D_B_VALID(D_B_VALID),
        .D_B_READY(D_B_READY),
        .D_AR_ID(D_AR_ID),
        .D_AR_ADDR(D_AR_ADDR),
        .D_AR_LEN(D_AR_LEN),
        .D_AR_SIZE(D_AR_SIZE),
        .D_AR_BURST(D_AR_BURST),
        .D_AR_LOCK(D_AR_LOCK),
        .D_AR_CACHE(D_AR_CACHE),
        .D_AR_PROT(D_AR_PROT),
        .D_AR_QOS(D_AR_QOS),
        .D_AR_VALID(D_AR_VALID),
        .D_AR_READY(D_AR_READY),
        .D_R_ID(D_R_ID),
        .D_R_DATA(D_R_DATA),
        .D_R_RESP(D_R_RESP),
        .D_R_LAST(D_R_LAST),
        .D_R_VALID(D_R_VALID),
        .D_R_READY(D_R_READY),
        .PC_OUT(PC_OUT)
    );

    //=============================================================
    // --------------------- Data AXI4 Bus ------------------------
    //=============================================================
    AXI4_Bus #(
        .DATA_W(`DATA_W),
        .ADDR_W(`ADDR_W),
        .ID_W(`AXI_ID_W),
        .BRAM_DEPTH(`DATA_BRAM_DEPTH),
        .BRAM_ADDR_W(`DATA_BRAM_ADDR_W)
    ) Data_AXI4_Bus (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AW_ID(D_AW_ID),
        .AW_ADDR(D_AW_ADDR),
        .AW_LEN(D_AW_LEN),
        .AW_SIZE(D_AW_SIZE),
        .AW_BURST(D_AW_BURST),
        .AW_LOCK(D_AW_LOCK),
        .AW_CACHE(D_AW_CACHE),
        .AW_PROT(D_AW_PROT),
        .AW_QOS(D_AW_QOS),
        .AW_VALID(D_AW_VALID),
        .AW_READY(D_AW_READY),
        .W_DATA(D_W_DATA),
        .W_STRB(D_W_STRB),
        .W_LAST(D_W_LAST),
        .W_VALID(D_W_VALID),
        .W_READY(D_W_READY),
        .B_ID(D_B_ID),
        .B_RESP(D_B_RESP),
        .B_VALID(D_B_VALID),
        .B_READY(D_B_READY),
        .AR_ID(D_AR_ID),
        .AR_ADDR(D_AR_ADDR),
        .AR_LEN(D_AR_LEN),
        .AR_SIZE(D_AR_SIZE),
        .AR_BURST(D_AR_BURST),
        .AR_LOCK(D_AR_LOCK),
        .AR_CACHE(D_AR_CACHE),
        .AR_PROT(D_AR_PROT),
        .AR_QOS(D_AR_QOS),
        .AR_VALID(D_AR_VALID),
        .AR_READY(D_AR_READY),
        .R_ID(D_R_ID),
        .R_DATA(D_R_DATA),
        .R_RESP(D_R_RESP),
        .R_LAST(D_R_LAST),
        .R_VALID(D_R_VALID),
        .R_READY(D_R_READY),
        .BRAM_EN(D_BRAM_EN),
        .BRAM_WE(D_BRAM_WE),
        .BRAM_ADDR(D_BRAM_ADDR),
        .BRAM_DIN(D_BRAM_DIN),
        .BRAM_DOUT(D_BRAM_DOUT)
    );

    //=============================================================
    // ---------------------- Data Memory -------------------------
    //=============================================================
    D_BRAM Data_Memory (
        .clka(ACLK),
        .ena(D_BRAM_EN),
        .wea(D_BRAM_WE),
        .addra(D_BRAM_ADDR),
        .dina(D_BRAM_DIN),
        .douta(D_BRAM_DOUT)
    );

endmodule
