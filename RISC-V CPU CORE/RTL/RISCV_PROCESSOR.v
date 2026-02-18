`include "SYSTEM_DEF.vh"

module RISCV_PROCESSOR(
    input ACLK,
    input ARESETn);

    // =========================================================================
    // I-Cache AXI signals
    // =========================================================================
    wire                    I_AR_VALID, I_AR_READY;
    wire [`PC_WIDTH-1:0]    I_AR_ADDR;
    wire                    I_R_VALID,  I_R_READY;
    wire [`DATA_WIDTH-1:0]  I_R_DATA;
    wire [`BRAM_ADDR_W-1:0] I_SLAVE_ADDR;
    wire [`DATA_WIDTH-1:0]  I_SLAVE_DOUT;

    // =========================================================================
    // D-Cache AXI signals
    // =========================================================================
    wire                    D_AR_VALID, D_AR_READY;
    wire [`ADDR_W-1:0]      D_AR_ADDR;
    wire                    D_R_VALID,  D_R_READY;
    wire [`DATA_W-1:0]      D_R_DATA;
    wire                    D_AW_VALID, D_AW_READY;
    wire [`ADDR_W-1:0]      D_AW_ADDR;
    wire                    D_W_VALID,  D_W_READY;
    wire [`DATA_W-1:0]      D_W_DATA;
    wire [`DATA_W/8-1:0]    D_W_STRB;
    wire                    D_B_VALID,  D_B_READY;

    // D-BRAM slave interface
    wire [3:0]              D_SLAVE_WE;
    wire [`BRAM_ADDR_W-1:0] D_SLAVE_ADDR;
    wire [`DATA_W-1:0]      D_SLAVE_DIN;
    wire [`DATA_W-1:0]      D_SLAVE_DOUT;

    // =========================================================================
    // Instruction BRAM (Vivado IP)
    // =========================================================================
    blk_mem_gen_0 Instruction_Mem (
        .addra(I_SLAVE_ADDR),
        .clka(ACLK),
        .douta(I_SLAVE_DOUT));

    // =========================================================================
    // Instruction AXI4-Lite Bus
    // =========================================================================
    AXI4_Lite_Bus Instruction_AXI4_Lite_Bus (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // Write channels - TIED OFF (instruction cache is read-only)
        .AW_VALID(1'b0),
        .AW_READY(),
        .AW_ADDR({`ADDR_W{1'b0}}),
        .W_VALID(1'b0),
        .W_READY(),
        .W_DATA({`DATA_W{1'b0}}),
        .W_STRB({(`DATA_W/8){1'b0}}),
        .B_VALID(),
        .B_READY(1'b0),
        .B_RESP(),

        // Read channels
        .AR_VALID(I_AR_VALID),
        .AR_READY(I_AR_READY),
        .AR_ADDR(I_AR_ADDR),
        .R_VALID(I_R_VALID),
        .R_READY(I_R_READY),
        .R_DATA(I_R_DATA),
        .R_RESP(),

        // BRAM interface
        .SLAVE_WE(),
        .SLAVE_ADDR(I_SLAVE_ADDR),
        .SLAVE_DIN(),
        .SLAVE_DOUT(I_SLAVE_DOUT));

    // =========================================================================
    // RISC-V CPU Core
    // =========================================================================
    RISCV_CPU RISC_V_CPU_inst(
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        // I-Cache AXI
        .I_AR_VALID(I_AR_VALID),
        .I_AR_ADDR(I_AR_ADDR),
        .I_AR_READY(I_AR_READY),
        .I_R_READY(I_R_READY),
        .I_R_VALID(I_R_VALID),
        .I_R_DATA(I_R_DATA),
        // D-Cache AXI
        .D_AR_VALID(D_AR_VALID),
        .D_R_READY(D_R_READY),
        .D_AR_ADDR(D_AR_ADDR),
        .D_AR_READY(D_AR_READY),
        .D_R_VALID(D_R_VALID),
        .D_R_DATA(D_R_DATA),
        .D_AW_VALID(D_AW_VALID),
        .D_AW_ADDR(D_AW_ADDR),
        .D_W_VALID(D_W_VALID),
        .D_W_DATA(D_W_DATA),
        .D_W_STRB(D_W_STRB),
        .D_B_READY(D_B_READY),
        .D_AW_READY(D_AW_READY),
        .D_W_READY(D_W_READY),
        .D_B_VALID(D_B_VALID));

    // =========================================================================
    // Data AXI4-Lite Bus
    // =========================================================================
    AXI4_Lite_Bus Data_AXI4_Lite_Bus (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // Write channels
        .AW_VALID(D_AW_VALID),
        .AW_READY(D_AW_READY),
        .AW_ADDR(D_AW_ADDR),
        .W_VALID(D_W_VALID),
        .W_READY(D_W_READY),
        .W_DATA(D_W_DATA),
        .W_STRB(D_W_STRB),
        .B_VALID(D_B_VALID),
        .B_READY(D_B_READY),
        .B_RESP(),

        // Read channels
        .AR_VALID(D_AR_VALID),
        .AR_READY(D_AR_READY),
        .AR_ADDR(D_AR_ADDR),
        .R_VALID(D_R_VALID),
        .R_READY(D_R_READY),
        .R_DATA(D_R_DATA),
        .R_RESP(),

        // BRAM slave interface
        .SLAVE_WE(D_SLAVE_WE),
        .SLAVE_ADDR(D_SLAVE_ADDR),
        .SLAVE_DIN(D_SLAVE_DIN),
        .SLAVE_DOUT(D_SLAVE_DOUT));

    // =========================================================================
    // Data BRAM (custom D_BRAM, supports TB dump via DataMem[i])
    // =========================================================================
    D_BRAM Data_Memory (
        .clka(ACLK),
        .wea(D_SLAVE_WE),
        .addra(D_SLAVE_ADDR),   // 10-bit word address from AXI bus
        .dina(D_SLAVE_DIN),
        .douta(D_SLAVE_DOUT));

endmodule
