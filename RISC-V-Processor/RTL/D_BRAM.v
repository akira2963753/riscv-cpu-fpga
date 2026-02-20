`include "SYSTEM_DEF.vh"

module D_BRAM(
    input clka,
    input [3:0] wea,
    input [`BRAM_ADDR_W-1:0] addra,      // 10-bit word address (from AXI4_Lite_Bus)
    input [`DATA_MEM_WIDTH-1:0] dina,
    output reg [`DATA_MEM_WIDTH-1:0] douta
);

    reg [7:0] DataMem [0:`DATA_MEM_SIZE - 1];
    integer i;
    always @(posedge clka) begin
        if(wea != 4'b0000) begin
            if(wea[0]) DataMem[{addra, 2'b00}  ] <= dina[7:0];
            if(wea[1]) DataMem[{addra, 2'b00}+1] <= dina[15:8];
            if(wea[2]) DataMem[{addra, 2'b00}+2] <= dina[23:16];
            if(wea[3]) DataMem[{addra, 2'b00}+3] <= dina[31:24];
        end
        else; // No write operation
        douta = {DataMem[{addra,2'b00}+3], DataMem[{addra,2'b00}+2],
                 DataMem[{addra,2'b00}+1], DataMem[{addra,2'b00}  ]};
    end

endmodule