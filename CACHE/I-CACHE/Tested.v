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
    // Clock and Reset
    input   wire                    ACLK,
    input   wire                    ARESETn,

    // CPU Fetch Interface
    input   wire                    CPU_REQ,
    input   wire    [ADDR_W-1:0]    CPU_REQ_ADDR,
    output  wire                    CPU_REQ_VALID,
    output  wire    [DATA_W-1:0]    CPU_REQ_DATA,

    // Cache Control
    output  wire                    BUSY
);

    // Internal Cache-to-Bus AXI4-Lite signals
    wire                    AR_VALID;
    wire                    AR_READY;
    wire    [ADDR_W-1:0]    AR_ADDR;
    wire                    R_VALID;
    wire                    R_READY;
    wire    [DATA_W-1:0]    R_DATA;

    // BRAM Interface signals
    wire    [DATA_W/8-1:0]  SLAVE_WE;
    wire    [ADDR_W-1:0]    SLAVE_ADDR;
    wire    [DATA_W-1:0]    SLAVE_DIN;
    wire    [DATA_W-1:0]    SLAVE_DOUT;

    // BRAM Instance
    blk_mem_gen_0 blk_mem_gen_0 (
        .addra(SLAVE_ADDR),
        .clka(ACLK),
        .douta(SLAVE_DOUT));

    // Instruction Cache - AXI4-Lite Master
    Cache Cache_inst (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // CPU Fetch Interface (external)
        .CPU_REQ(CPU_REQ),
        .CPU_REQ_ADDR(CPU_REQ_ADDR),
        .CPU_REQ_VALID(CPU_REQ_VALID),
        .CPU_REQ_DATA(CPU_REQ_DATA),

        // Control
        .BUSY(BUSY),

        // AXI4-Lite Read Master → Bus Slave
        .AR_VALID(AR_VALID),
        .AR_ADDR(AR_ADDR),
        .R_READY(R_READY),
        .AR_READY(AR_READY),
        .R_VALID(R_VALID),
        .R_DATA(R_DATA)
    );

    // AXI4-Lite Bus - Protocol Handler
    AXI4_Lite_Bus #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .BRAM_DEPTH(BRAM_DEPTH),
        .BRAM_ADDR_W(BRAM_ADDR_W)
    ) AXI4_Lite_Bus_inst (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // Write channels - TIED OFF (no writes from Cache)
        .AW_VALID(1'b0),
        .AW_READY(), // Leave unconnected
        .AW_ADDR({ADDR_W{1'b0}}),
        .W_VALID(1'b0),
        .W_READY(), // Leave unconnected
        .W_DATA({DATA_W{1'b0}}),
        .W_STRB({DATA_W/8{1'b0}}),
        .B_VALID(), // Leave unconnected
        .B_READY(1'b0),
        .B_RESP(), // Leave unconnected

        // Read channels - FROM CACHE
        .AR_VALID(AR_VALID),
        .AR_READY(AR_READY),
        .AR_ADDR(AR_ADDR),
        .R_VALID(R_VALID),
        .R_READY(R_READY),
        .R_DATA(R_DATA),
        .R_RESP(),          // Leave unconnected (always OKAY)

        // BRAM interface (unchanged)
        .SLAVE_WE(SLAVE_WE),
        .SLAVE_ADDR(SLAVE_ADDR),
        .SLAVE_DIN(SLAVE_DIN),
        .SLAVE_DOUT(SLAVE_DOUT)
    );

endmodule