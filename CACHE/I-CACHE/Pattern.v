module Pattern();
    
    parameter DATA_W  = 32;
    parameter ADDR_W  = 32;
    parameter BRAM_DEPTH = 1024;
    parameter BRAM_ADDR_W = $clog2(BRAM_DEPTH);

    reg                     ACLK;
    reg                     ARESETn;
    reg                     CPU_REQ;
    reg     [ADDR_W-1:0]    CPU_REQ_ADDR;
    wire                    CPU_REQ_VALID;
    wire    [DATA_W-1:0]    CPU_REQ_DATA;
    wire                    BUSY;
    
    Tested #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .BRAM_DEPTH(BRAM_DEPTH),
        .BRAM_ADDR_W(BRAM_ADDR_W)
    ) Tested_inst (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // CPU Fetch Interface
        .CPU_REQ(CPU_REQ),
        .CPU_REQ_ADDR(CPU_REQ_ADDR),
        .CPU_REQ_VALID(CPU_REQ_VALID),
        .CPU_REQ_DATA(CPU_REQ_DATA),
        .BUSY(BUSY)
    );

    always #5 ACLK = ~ACLK; // 100MHz clock

    // Expected data memory for verification
    reg [DATA_W-1:0] expected_data [0:BRAM_DEPTH-1];
    integer i;

    initial $readmemh("C:/Users/harry/Desktop/Project/CACHE/I-CACHE/Mem_Data/test_data.mem", expected_data);

    initial begin
        ACLK = 0;
        ARESETn = 1;
        CPU_REQ = 0;
        CPU_REQ_ADDR = 0;

        #120;
        @(negedge ACLK) ARESETn = 0;
        @(negedge ACLK) ARESETn = 1;

        // Test sequence
        for(i=0; i<BRAM_DEPTH; i=i+1) begin
            READ_DATA(CPU_REQ_ADDR, expected_data[i]);
            CPU_REQ_ADDR = CPU_REQ_ADDR + 4;
        end
        #100 $display("All TEST PASSED ! ! ! "); 
        #10 $finish;

    end

    task READ_DATA;
        input [ADDR_W-1:0] addr;
        input [DATA_W-1:0] expected;
        begin
            @(negedge ACLK);
            CPU_REQ = 1;
            CPU_REQ_ADDR = addr;
            wait(CPU_REQ_VALID);
            $display("Read from address %h, Get data = %h, Expected = %h", addr, CPU_REQ_DATA, expected);
            if(CPU_REQ_DATA != expected) begin
                $display("Error: Expected data %h, Got data %h", expected, CPU_REQ_DATA);
                #10 $finish;
            end
            @(negedge ACLK);
            CPU_REQ = 0;
        end
    endtask
    
endmodule