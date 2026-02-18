`include "SYSTEM_DEF.vh"

module Hazard_Unit(
    input [`ADDR_WIDTH - 1:0] Rs1Addr,
    input [`ADDR_WIDTH - 1:0] Rs2Addr,
    input [`ADDR_WIDTH - 1:0] RdAddr,
    input EX_Mem_r,
    input  D_Cache_Busy,      // D-Cache stall request
    output reg IF_ID_w,
    output reg ID_EX_Flush_0,
    output reg Pipeline_Stall // Freeze ID_EX / EX_MEM / MEM_WB
);

    always @(*) begin
        if (D_Cache_Busy) begin
            // D-Cache stall: freeze entire pipeline, no flush
            IF_ID_w       = 1'b0;
            ID_EX_Flush_0 = 1'b0;
            Pipeline_Stall = 1'b1;
        end
        else if (EX_Mem_r && ((RdAddr==Rs1Addr)||(RdAddr==Rs2Addr))) begin
            // Load-use hazard: stall IF/ID, insert bubble into ID_EX
            IF_ID_w       = 1'b0;
            ID_EX_Flush_0 = 1'b1;
            Pipeline_Stall = 1'b0;
        end
        else begin
            IF_ID_w       = 1'b1;
            ID_EX_Flush_0 = 1'b0;
            Pipeline_Stall = 1'b0;
        end
    end

endmodule