`include "SYSTEM_DEF.vh"

module RISCV_PROCESSOR_tb ();
    reg ACLK;
    reg ARESETn;
    wire [`PC_WIDTH-1:0] PC_OUT;

    reg [7:0] DataMem [0:`DATA_MEM_SIZE - 1];
    integer i,j;
    integer register_file,dm_file;
    RISCV_PROCESSOR test(ACLK,ARESETn,PC_OUT);

    CHECKER #(
        .DATA_W(`DATA_W),
        .ADDR_W(`ADDR_W),
        .ID_W(`AXI_ID_W),
        .BRAM_DEPTH(`BRAM_DEPTH)
    ) Instruction_AXI4_Checker (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AW_ID(test.I_AW_ID),
        .AW_ADDR(test.I_AW_ADDR),
        .AW_LEN(test.I_AW_LEN),
        .AW_SIZE(test.I_AW_SIZE),
        .AW_BURST(test.I_AW_BURST),
        .AW_LOCK(test.I_AW_LOCK),
        .AW_CACHE(test.I_AW_CACHE),
        .AW_PROT(test.I_AW_PROT),
        .AW_QOS(test.I_AW_QOS),
        .AW_VALID(test.I_AW_VALID),
        .AW_READY(test.I_AW_READY),
        .W_DATA(test.I_W_DATA),
        .W_STRB(test.I_W_STRB),
        .W_LAST(test.I_W_LAST),
        .W_VALID(test.I_W_VALID),
        .W_READY(test.I_W_READY),
        .B_ID(test.I_B_ID),
        .B_RESP(test.I_B_RESP),
        .B_VALID(test.I_B_VALID),
        .B_READY(test.I_B_READY),
        .AR_ID(test.I_AR_ID),
        .AR_ADDR(test.I_AR_ADDR),
        .AR_LEN(test.I_AR_LEN),
        .AR_SIZE(test.I_AR_SIZE),
        .AR_BURST(test.I_AR_BURST),
        .AR_LOCK(test.I_AR_LOCK),
        .AR_CACHE(test.I_AR_CACHE),
        .AR_PROT(test.I_AR_PROT),
        .AR_QOS(test.I_AR_QOS),
        .AR_VALID(test.I_AR_VALID),
        .AR_READY(test.I_AR_READY),
        .R_ID(test.I_R_ID),
        .R_DATA(test.I_R_DATA),
        .R_RESP(test.I_R_RESP),
        .R_LAST(test.I_R_LAST),
        .R_VALID(test.I_R_VALID),
        .R_READY(test.I_R_READY)
    );

    CHECKER #(
        .DATA_W(`DATA_W),
        .ADDR_W(`ADDR_W),
        .ID_W(`AXI_ID_W),
        .BRAM_DEPTH(`DATA_BRAM_DEPTH)
    ) Data_AXI4_Checker (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AW_ID(test.D_AW_ID),
        .AW_ADDR(test.D_AW_ADDR),
        .AW_LEN(test.D_AW_LEN),
        .AW_SIZE(test.D_AW_SIZE),
        .AW_BURST(test.D_AW_BURST),
        .AW_LOCK(test.D_AW_LOCK),
        .AW_CACHE(test.D_AW_CACHE),
        .AW_PROT(test.D_AW_PROT),
        .AW_QOS(test.D_AW_QOS),
        .AW_VALID(test.D_AW_VALID),
        .AW_READY(test.D_AW_READY),
        .W_DATA(test.D_W_DATA),
        .W_STRB(test.D_W_STRB),
        .W_LAST(test.D_W_LAST),
        .W_VALID(test.D_W_VALID),
        .W_READY(test.D_W_READY),
        .B_ID(test.D_B_ID),
        .B_RESP(test.D_B_RESP),
        .B_VALID(test.D_B_VALID),
        .B_READY(test.D_B_READY),
        .AR_ID(test.D_AR_ID),
        .AR_ADDR(test.D_AR_ADDR),
        .AR_LEN(test.D_AR_LEN),
        .AR_SIZE(test.D_AR_SIZE),
        .AR_BURST(test.D_AR_BURST),
        .AR_LOCK(test.D_AR_LOCK),
        .AR_CACHE(test.D_AR_CACHE),
        .AR_PROT(test.D_AR_PROT),
        .AR_QOS(test.D_AR_QOS),
        .AR_VALID(test.D_AR_VALID),
        .AR_READY(test.D_AR_READY),
        .R_ID(test.D_R_ID),
        .R_DATA(test.D_R_DATA),
        .R_RESP(test.D_R_RESP),
        .R_LAST(test.D_R_LAST),
        .R_VALID(test.D_R_VALID),
        .R_READY(test.D_R_READY)
    );

    initial begin
        ACLK = 0;
        ARESETn = 1;
        #1 ARESETn = 0;
        repeat(3) @(negedge ACLK);
        ARESETn = 1;
        #10000 begin
            register_file = $fopen("C:/Users/harry/Desktop/Project/risc-v/RISC-V-Processor/Testbench/RF.out", "w");
            if (register_file) begin
                $fdisplay(register_file, "// Register File Contents with Index");
                $fdisplay(register_file, "// Format: [Index] Data");
                for (i = 0; i < `GPR_SIZE; i = i + 1) begin
                    $fdisplay(register_file, "[%0d] %h", i, test.RISC_V_CPU_inst.Register_File.GPR[i]);
                end
                $fclose(register_file);
                $display("Register File written to RF.out");
            end
            else $display("Failed to open RF.out");

            dm_file = $fopen("C:/Users/harry/Desktop/Project/risc-v/RISC-V-Processor/Testbench/DM.out", "w");
            if (dm_file) begin
                $fdisplay(dm_file, "// Data Memory Contents with Address");
                $fdisplay(dm_file, "// Format: [Address] Data");
                for (i = 0; i < `DATA_MEM_SIZE / 4; i = i + 1) begin
                    {DataMem[i*4+3],DataMem[i*4+2],DataMem[i*4+1],DataMem[i*4]} = test.Data_Memory.DataMem[i];
                end
                for (i = 0; i < `DATA_MEM_SIZE; i = i + 1) begin
                    $fdisplay(dm_file, "[%0d] %h", i, DataMem[i]);
                end
                $fclose(dm_file);
                $display("Data Memory written to DM.out");
            end
            else $display("Failed to open DM.out");
        end
        #10 $finish;
    end

    always #5 ACLK <= ~ ACLK;

    initial begin : Preprocess
        //$readmemh("C:/Users/harry/Desktop/Project/RISCV/Five-Stage-Pipelined-CPU/Testbench/IM.dat", InstrMem);
        $readmemh("C:/Users/harry/Desktop/Project/risc-v/RISC-V-Processor/Testbench/DM.dat", DataMem);
        for (i = 0; i < `DATA_MEM_SIZE / 4; i = i + 1) begin
            test.Data_Memory.DataMem[i] = {DataMem[i*4+3],DataMem[i*4+2],DataMem[i*4+1],DataMem[i*4]};
        end
        $display("Initialize the Instr_Mem & Data_Mem");
    end
endmodule
