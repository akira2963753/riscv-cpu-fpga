/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    AXI_Lite_Bus.v
* Project:      RISC-V-CPU Design - AXI Bus
* Module:       AXI_Lite_Bus
* Author:       Marco <harry2963753@gmail.com>
* Created:      2026/02/07
* Modified:     2025/02/08
* Version:      1.0
* Comment Opt:  Claude Code
******************************************************************************/

module AXI4_Lite_Bus #(
    parameter DATA_W  = 32,
    parameter ADDR_W  = 32,
    parameter BRAM_DEPTH = 1024,
    parameter BRAM_ADDR_W = $clog2(BRAM_DEPTH)
)(
    // ========================================================================
    // --------------------------- Clock and Reset ---------------------------
    // ========================================================================
    input   wire    ACLK,
    input   wire    ARESETn,

    // ========================================================================
    // ------------------- AXI4-Lite Master Interface ------------------------
    // ========================================================================

    // Write Address Channel (AW)
    input   wire    AW_VALID,
    output  reg     AW_READY,
    input   wire    [ADDR_W-1:0]    AW_ADDR,

    // Write Data Channel (W)
    input   wire    W_VALID,
    output  reg     W_READY,
    input   wire    [DATA_W-1:0]    W_DATA,
    input   wire    [DATA_W/8-1:0]  W_STRB,

    // Write Response Channel (B)
    output  reg     B_VALID,
    input   wire    B_READY,
    output  wire    [1:0]   B_RESP,

    // Read Address Channel (AR)
    input   wire    AR_VALID,
    output  reg     AR_READY,
    input   wire    [ADDR_W-1:0]    AR_ADDR,

    // Read Data Channel (R)
    output  reg     R_VALID,
    input   wire    R_READY,
    output  reg     [DATA_W-1:0]    R_DATA,
    output  wire    [1:0]   R_RESP,

    // ========================================================================
    // ----------------------- BRAM Slave Interface --------------------------
    // ========================================================================
    output  reg     [DATA_W/8-1:0]      SLAVE_WE,
    output  reg     [BRAM_ADDR_W-1:0]   SLAVE_ADDR,
    output  reg     [DATA_W-1:0]        SLAVE_DIN,
    input   wire    [DATA_W-1:0]        SLAVE_DOUT
);

    // ========================================================================
    // ----------------------- Response Signals ------------------------------
    // ========================================================================
    assign B_RESP = 2'b00;  // OKAY - Write always succeeds
    assign R_RESP = 2'b00;  // OKAY - Read always succeeds

    // ========================================================================
    // ----------------------- Internal Registers ----------------------------
    // ========================================================================
    // Write channel pending flags and data registers
    reg     AW_PENDING;                     
    reg     [BRAM_ADDR_W-1:0]    AW_ADDR_REG;  
    reg     W_PENDING;                  
    reg     [DATA_W-1:0]    W_DATA_REG;     
    reg     [DATA_W/8-1:0]  W_STRB_REG;    

    // Read channel pending flag and address register
    reg     R_PENDING;                    
    reg     [ADDR_W-1:0]    AR_ADDR_REG; 

    // Control signals
    wire    DO_WRITE, DO_READ;

    // ========================================================================
    // -------------------- Write Address Channel (AW) -----------------------
    // ========================================================================
    always @(*) AW_READY = ~AW_PENDING;

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            AW_PENDING  <= 0;
            AW_ADDR_REG <= 0;
        end
        else begin
            if(AW_VALID && AW_READY) begin
                AW_PENDING  <= 1'b1;
                AW_ADDR_REG <= AW_ADDR[BRAM_ADDR_W+1:2]; 
            end
            if(AW_PENDING && W_PENDING) AW_PENDING  <= 0;
        end
    end

    // ========================================================================
    // --------------------- Write Data Channel (W) --------------------------
    // ========================================================================
    always @(*) W_READY = ~W_PENDING;

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            W_PENDING   <= 0;
            W_DATA_REG  <= 0;
            W_STRB_REG  <= 0;
        end
        else begin
            if(W_VALID && W_READY) begin
                W_PENDING   <= 1'b1;
                W_DATA_REG  <= W_DATA;
                W_STRB_REG  <= W_STRB;  
            end
          
            if(AW_PENDING && W_PENDING) begin
                W_PENDING   <= 1'b0;
            end
        end
    end

    // ========================================================================
    // -------------------- BRAM Control Logic -------------------------------
    // ========================================================================

    assign DO_WRITE = AW_PENDING && W_PENDING;
    assign DO_READ  = AR_VALID && AR_READY;

    always @(*) begin
        if(DO_WRITE) begin
            SLAVE_WE    = W_STRB_REG;        
            SLAVE_ADDR  = AW_ADDR_REG;          
            SLAVE_DIN   = W_DATA_REG;       
        end
        else if(DO_READ) begin
            SLAVE_WE    = 4'b0000;             
            SLAVE_ADDR  = AR_ADDR[BRAM_ADDR_W+1:2];  
            SLAVE_DIN   = 0;                 
        end
        else begin
            SLAVE_WE    = 4'b0000;       
            SLAVE_ADDR  = 0;
            SLAVE_DIN   = 0;
        end
    end

    // ========================================================================
    // ------------------- Write Response Channel (B) ------------------------
    // ========================================================================

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) B_VALID <= 0;
        else if(|SLAVE_WE) B_VALID <= 1'b1;
        else if(B_VALID && B_READY) B_VALID <= 0;
    end

    // ========================================================================
    // -------------------- Read Address Channel (AR) ------------------------
    // ========================================================================
    always @(*) AR_READY = (~R_PENDING) && (~R_VALID) && (~DO_WRITE);

    // ========================================================================
    // --------------------- Read Data Channel (R) ---------------------------
    // ========================================================================

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            R_PENDING   <= 0;
            R_VALID     <= 0;
            R_DATA      <= 0;
        end
        else begin
            if(DO_READ) R_PENDING <= 1'b1;
            if(R_PENDING) begin
                R_PENDING   <= 0;
                R_VALID     <= 1'b1;
                R_DATA      <= SLAVE_DOUT; 
            end
            if(R_VALID && R_READY) R_VALID  <= 0;
        end
    end

endmodule