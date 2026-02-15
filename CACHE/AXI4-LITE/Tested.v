/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    Tested.v
* Project:      RISC-V-CPU Design - AXI Bus
* Module:       Tested
* Author:       Marco <harry2963753@gmail.com>
* Created:      2026/02/07
* Modified:     2025/02/08
* Version:      1.0
******************************************************************************/

module Tested #(
    parameter DATA_W  = 32,
    parameter ADDR_W  = 32,
    parameter BRAM_DEPTH = 1024,
    parameter BRAM_ADDR_W = $clog2(BRAM_DEPTH)
)(
    input   wire    ACLK,
    input   wire    ARESETn,
    input   wire    AW_VALID,
    output  wire     AW_READY,
    input   wire    [ADDR_W-1:0]    AW_ADDR,
    input   wire    W_VALID,
    output  wire     W_READY,
    input   wire    [DATA_W-1:0]    W_DATA,
    input   wire    [DATA_W/8-1:0]  W_STRB,
    output  wire     B_VALID,
    input   wire    B_READY,
    output  wire    [1:0]   B_RESP,
    input   wire    AR_VALID,
    output  wire     AR_READY,
    input   wire    [ADDR_W-1:0]    AR_ADDR,
    output  wire     R_VALID,
    input   wire    R_READY,
    output  wire    [DATA_W-1:0]    R_DATA,
    output  wire    [1:0]   R_RESP
);

    wire    [DATA_W/8-1:0] SLAVE_WE;
    wire    [ADDR_W-1:0]    SLAVE_ADDR;
    wire    [DATA_W-1:0]    SLAVE_DIN;
    wire    [DATA_W-1:0]    SLAVE_DOUT;

    blk_mem_gen_0 blk_mem_gen_0 (
        .addra(SLAVE_ADDR),
        .clka(ACLK),
        .dina(SLAVE_DIN),
        .douta(SLAVE_DOUT),
        .wea(SLAVE_WE));

    AXI4_Lite_Bus #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .BRAM_DEPTH(BRAM_DEPTH),
        .BRAM_ADDR_W(BRAM_ADDR_W)) 
        AXI4_Lite_Bus_inst (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AW_VALID(AW_VALID),
        .AW_READY(AW_READY),
        .AW_ADDR(AW_ADDR),
        .W_VALID(W_VALID),
        .W_READY(W_READY),
        .W_DATA(W_DATA),
        .W_STRB(W_STRB),
        .B_VALID(B_VALID),
        .B_READY(B_READY),
        .B_RESP(B_RESP),
        .AR_VALID(AR_VALID),
        .AR_READY(AR_READY),
        .AR_ADDR(AR_ADDR),
        .R_VALID(R_VALID),
        .R_READY(R_READY),
        .R_DATA(R_DATA),
        .R_RESP(R_RESP),
        .SLAVE_WE(SLAVE_WE),
        .SLAVE_ADDR(SLAVE_ADDR),
        .SLAVE_DIN(SLAVE_DIN),
        .SLAVE_DOUT(SLAVE_DOUT));

endmodule