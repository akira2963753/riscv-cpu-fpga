`include "SYSTEM_DEF.vh"

module ALU(
    input [31:0] Src1,
    input [31:0] Src2,
    input [4:0] ALU_Ctrl_op,
    output reg [31:0] ALU_Result,
    output Zero_Flag
);
    wire signed [31:0] Src1_Signed,Src2_Signed;
    reg signed [63:0] Mul_Result;
    assign Src1_Signed = Src1;
    assign Src2_Signed = Src2;
    assign Zero_Flag = (ALU_Result==0);

    always @(*) begin
        case(ALU_Ctrl_op)
            `ALU_CTRL_ADD   : begin
                Mul_Result = 0;
                ALU_Result = Src1 + Src2;
            end
            `ALU_CTRL_SUB   : begin
                Mul_Result = 0;
                ALU_Result = Src1 - Src2;
            end
            `ALU_CTRL_SLT   : begin
                Mul_Result = 0;
                ALU_Result = (Src1_Signed < Src2_Signed);
            end
            `ALU_CTRL_SLTU  : begin
                Mul_Result = 0;
                ALU_Result = (Src1 < Src2);
            end
            `ALU_CTRL_GE    : begin
                Mul_Result = 0;
                ALU_Result = (Src1_Signed >= Src2_Signed);
            end
            `ALU_CTRL_GEU   : begin
                Mul_Result = 0;
                ALU_Result = (Src1 >= Src2);
            end
            `ALU_CTRL_AND   : begin
                Mul_Result = 0;
                ALU_Result = Src1 & Src2;
            end
            `ALU_CTRL_OR    : begin
                Mul_Result = 0;
                ALU_Result = Src1 | Src2;
            end
            `ALU_CTRL_XOR   : begin
                Mul_Result = 0;
                ALU_Result = Src1 ^ Src2;
            end
            `ALU_CTRL_SLL   : begin
                Mul_Result = 0;
                ALU_Result = Src1 << Src2[4:0];
            end
            `ALU_CTRL_SRL   : begin
                Mul_Result = 0;
                ALU_Result = Src1 >> Src2[4:0];
            end
            `ALU_CTRL_SRA   : begin
                Mul_Result = 0;
                ALU_Result = Src1_Signed >>> Src2[4:0];
            end
            `ALU_CTRL_MUL   : begin
                Mul_Result = Src1_Signed * Src2_Signed;
                ALU_Result = Mul_Result[31:0];
            end
            `ALU_CTRL_DIV   : begin 
                Mul_Result = 0;
                ALU_Result = Src1_Signed / Src2_Signed;
            end
            `ALU_CTRL_REM   : begin
                Mul_Result = 0;
                ALU_Result = Src1_Signed % Src2_Signed;
            end
            `ALU_CTRL_MULH  : begin
                Mul_Result = Src1_Signed * Src2_Signed;
                ALU_Result = Mul_Result[63:32];                
            end
            `ALU_CTRL_MULHSU: begin
                // MULHSU: signed × unsigned 注意這裡無號數 x 有號數要加上 $sigend 然後做 Sign extend
                Mul_Result = Src1_Signed * $signed({1'b0, Src2});
                ALU_Result = Mul_Result[63:32];
            end
            `ALU_CTRL_MULHU : begin
                Mul_Result = Src1 * Src2;
                ALU_Result = Mul_Result[63:32];                  
            end
            `ALU_CTRL_DIVU  : begin
                Mul_Result = 0;
                ALU_Result = Src1 / Src2;
            end
            `ALU_CTRL_REMU  : begin
                Mul_Result = 0;
                ALU_Result = Src1 % Src2;   
            end
            default         : begin
                Mul_Result = 0;
                ALU_Result = 0;         
            end
        endcase
    end
endmodule