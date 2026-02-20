`include "SYSTEM_DEF.vh"

module D_Cache (
    input ACLK,
    input ARESETn,
    
    // CPU Fetch
    input CPU_REQ,
    input [`ADDR_W-1:0] CPU_REQ_ADDR,
    output CPU_REQ_VALID,
    output [`DATA_W-1:0] CPU_REQ_DATA,

    // CPU Write Interface
    input CPU_WR_EN,
    input [`DATA_W-1:0] CPU_WR_DATA,
    input [`DATA_W/8-1:0] CPU_WR_STRB,

    // Control
    output BUSY,

    // AXI Read Master Output (Slave Input)
    output reg AR_VALID,
    output reg R_READY,
    output reg [`ADDR_W-1:0] AR_ADDR,

    // AXI Read Master Input (Slave Output)
    input AR_READY,
    input R_VALID,
    input [`DATA_W-1:0] R_DATA,

    // AXI Write Master Output (Slave Input)
    output reg AW_VALID,
    output reg [`ADDR_W-1:0] AW_ADDR,
    output reg W_VALID,
    output reg [`DATA_W-1:0] W_DATA,
    output reg [`DATA_W/8-1:0] W_STRB,
    output reg B_READY,

    // AXI Write Master Input (Slave Output)
    input AW_READY,
    input W_READY,
    input B_VALID
);

    // FSM
    localparam [2:0] IDLE = 3'd0, CMP = 3'd1, MREQ = 3'd2, REFILL = 3'd3, READ = 3'd4, WRITE = 3'd5, WRITE_WAIT = 3'd6;
    reg [2:0] STATE, NEXT_STATE;    

    integer i,j;
     
    // Instruction Address : TAG | INDEX | WORD_OFFEST | 00
    wire [`TAG_WIDTH - 1 :0] TAG;
    wire [`INDEX_WIDTH - 1 :0] INDEX;
    wire [`OFFSET_WIDTH - 1 :0] OFFSET;
    wire [`WORD_OFFEST_WIDTH - 1 :0] WORD_OFFEST;

    assign TAG = CPU_REQ_ADDR[`ADDR_W - 1 : `ADDR_W - `TAG_WIDTH];
    assign INDEX = CPU_REQ_ADDR[`ADDR_W - `TAG_WIDTH - 1 : `ADDR_W - `TAG_WIDTH - `INDEX_WIDTH];
    assign OFFSET = CPU_REQ_ADDR[`OFFSET_WIDTH - 1 : 0];
    assign WORD_OFFEST = CPU_REQ_ADDR[`OFFSET_WIDTH - 1 : `OFFSET_WIDTH - `WORD_OFFEST_WIDTH];

    // Cache
    reg [`TAG_WIDTH - 1 :0] TAG_ARRAY [0:`WAY-1][0:`SET_NUM-1];
    reg [`DATA_W - 1 :0] DATA_ARRAY [0:`WAY-1][0:`SET_NUM-1][0:`BLOCK_WORD_SIZE-1];
    reg VALID_ARRAY [0:`WAY-1][0:`SET_NUM-1];
    reg LRU [0:`SET_NUM-1];

    // Cache Hit Net
    wire CACHE_HIT, HIT_WAY, HIT0, HIT1;
    wire EMPTY;
    reg [2:0] REFILL_CNT;

    // victim
    reg VICTIM_WAY;
    reg [`INDEX_WIDTH - 1 :0] MISS_INDEX;
    reg [`TAG_WIDTH - 1 :0] MISS_TAG;
    reg [`WORD_OFFEST_WIDTH - 1 :0] MISS_WORD_OFFEST;
    reg RESP_WAY;
    reg [`INDEX_WIDTH - 1 :0] RESP_INDEX;
    reg [`WORD_OFFEST_WIDTH - 1 :0] RESP_WORD_OFFEST;

    // Write operation registers
    reg [`ADDR_W-1:0] WR_ADDR;
    reg [`DATA_W-1:0] WR_DATA_REG;
    reg [`DATA_W/8-1:0] WR_STRB_REG;
    reg WR_HIT;

    assign HIT0 = VALID_ARRAY[0][INDEX] && (TAG_ARRAY[0][INDEX] == TAG);
    assign HIT1 = VALID_ARRAY[1][INDEX] && (TAG_ARRAY[1][INDEX] == TAG);

    assign CACHE_HIT = HIT0 | HIT1;
    assign HIT_WAY = HIT1;
    assign EMPTY = !VALID_ARRAY[0][INDEX] | !VALID_ARRAY[1][INDEX];

    assign CPU_REQ_DATA = ((STATE==CMP && CACHE_HIT))? DATA_ARRAY[HIT_WAY][INDEX][WORD_OFFEST] :
                          (STATE==READ)? DATA_ARRAY[RESP_WAY][RESP_INDEX][RESP_WORD_OFFEST] : `NOP;
    assign CPU_REQ_VALID = (STATE==CMP && CACHE_HIT) || (STATE==READ);
    assign BUSY = (STATE != READ) && (STATE != IDLE) &&
                  !(STATE == CMP && (CACHE_HIT || CPU_WR_EN));
    
    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            for(i = 0; i < `SET_NUM; i = i + 1) begin
                LRU[i] <= 0;
                for(j = 0; j < `WAY; j = j + 1) begin
                    VALID_ARRAY[j][i] <= 0;
                    TAG_ARRAY[j][i] <= 0;
                end
            end
            REFILL_CNT <= 0;
            AR_VALID <= 0;
            R_READY <= 0;
            AR_ADDR <= 0;
            VICTIM_WAY <= 0;
            MISS_INDEX <= 0;
            MISS_TAG <= 0;
            RESP_INDEX <= 0;
            RESP_WORD_OFFEST <= 0;
            // Write signals
            AW_VALID <= 0;
            AW_ADDR <= 0;
            W_VALID <= 0;
            W_DATA <= 0;
            W_STRB <= 0;
            B_READY <= 0;
            WR_ADDR <= 0;
            WR_DATA_REG <= 0;
            WR_STRB_REG <= 0;
            WR_HIT <= 0;
        end
        else begin
            case(STATE)
                IDLE: begin
                    // Close AXI
                    AR_VALID <= 0;
                    R_READY <= 0;
                    AW_VALID <= 0;
                    W_VALID <= 0;
                    B_READY <= 0;
                end
                CMP : begin
                    if(CPU_WR_EN) begin  // Write operation
                        // Save write information
                        WR_ADDR <= CPU_REQ_ADDR;
                        WR_DATA_REG <= CPU_WR_DATA;
                        WR_STRB_REG <= CPU_WR_STRB;
                        WR_HIT <= CACHE_HIT;

                        // Write Hit: Update Cache
                        if(CACHE_HIT) begin
                            // Partial write using strobe
                            for(i = 0; i < `DATA_W/8; i = i + 1) begin
                                if(CPU_WR_STRB[i]) begin
                                    DATA_ARRAY[HIT_WAY][INDEX][WORD_OFFEST][i*8 +: 8]
                                        <= CPU_WR_DATA[i*8 +: 8];
                                end
                            end
                            LRU[INDEX] <= ~HIT_WAY;  // Update LRU
                        end
                        // Write Miss: Don't update Cache (No-Write Allocate)

                        // Prepare AXI Write
                        AW_ADDR <= CPU_REQ_ADDR;
                        AW_VALID <= 1;
                        W_DATA <= CPU_WR_DATA;
                        W_STRB <= CPU_WR_STRB;
                        W_VALID <= 1;
                        B_READY <= 1;
                    end
                    else if(CACHE_HIT) begin  // Read Hit
                        RESP_WAY <= HIT_WAY;
                        RESP_INDEX <= INDEX;
                        RESP_WORD_OFFEST <= WORD_OFFEST;
                        LRU[INDEX] <= ~HIT_WAY;
                    end
                    else begin  // Read Miss
                        // Choose Victim
                        if(EMPTY) VICTIM_WAY <= !VALID_ARRAY[0][INDEX];
                        else VICTIM_WAY <= LRU[INDEX];

                        // Fix Miss
                        MISS_INDEX <= INDEX;
                        MISS_TAG <= TAG;
                        MISS_WORD_OFFEST <= WORD_OFFEST;

                        // Align AR_ADDR to block boundary
                        AR_ADDR <= {CPU_REQ_ADDR[`ADDR_W-1:`OFFSET_WIDTH], {`OFFSET_WIDTH{1'b0}}};
                        R_READY <= 1; // Ready to receive data
                        REFILL_CNT <= 0;
                        AR_VALID <= 1; // ADDRess valid for new transaction
                    end
                end
                MREQ : begin  // Wait for AR handshake
                    if(AR_READY && AR_VALID) begin
                        AR_VALID <= 0;
                        //R_READY <= 1;
                    end
                end
                REFILL : begin
                    if(R_VALID && R_READY) begin
                        // Store received word
                        DATA_ARRAY[VICTIM_WAY][MISS_INDEX][REFILL_CNT] <= R_DATA;
                        R_READY <= 0;  // Deassert after handshake

                        if(REFILL_CNT == 3'd7) begin  // Last word (8th word)
                            // Update cache metadata
                            VALID_ARRAY[VICTIM_WAY][MISS_INDEX] <= 1;
                            TAG_ARRAY[VICTIM_WAY][MISS_INDEX] <= MISS_TAG;
                            LRU[MISS_INDEX] <= ~VICTIM_WAY;

                            // Update response registers
                            RESP_WAY <= VICTIM_WAY;
                            RESP_INDEX <= MISS_INDEX;
                            RESP_WORD_OFFEST <= MISS_WORD_OFFEST;

                            REFILL_CNT <= 0;  // Reset for next miss
                        end
                        else begin
                            // More words needed - prepare next AR request
                            REFILL_CNT <= REFILL_CNT + 1;
                            AR_ADDR <= AR_ADDR + 4;  // Increment to next word
                            AR_VALID <= 1;           // Request next word
                            R_READY <= 1;           // Ready for next word
                        end
                    end
                end
                WRITE: begin
                    // Wait for AXI handshakes to complete
                    if(AW_VALID && AW_READY) AW_VALID <= 0;
                    if(W_VALID && W_READY) W_VALID <= 0;
                end
                WRITE_WAIT: begin
                    // Wait for write response
                    if(B_VALID && B_READY) begin
                        B_READY <= 0;
                    end
                end
            endcase
        end
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) STATE <= IDLE;
        else STATE <= NEXT_STATE;
    end

    always @(*) begin
        case(STATE)
            IDLE: NEXT_STATE = (CPU_REQ || CPU_WR_EN)? CMP : IDLE;

            CMP: begin
                if(CPU_WR_EN) begin
                    NEXT_STATE = WRITE;  // Write operation goes to WRITE state
                end
                else if(CPU_REQ) begin
                    NEXT_STATE = (CACHE_HIT)? CMP : MREQ;  // Original read logic
                end
                else begin
                    NEXT_STATE = IDLE;
                end
            end

            WRITE: begin
                // AW and W both handshake complete, wait for response
                if((!AW_VALID || (AW_VALID && AW_READY)) &&
                   (!W_VALID || (W_VALID && W_READY))) begin
                    NEXT_STATE = WRITE_WAIT;
                end
                else begin
                    NEXT_STATE = WRITE;
                end
            end

            WRITE_WAIT: begin
                if(B_VALID && B_READY) begin
                    NEXT_STATE = (CPU_REQ || CPU_WR_EN)? CMP : IDLE;
                end
                else begin
                    NEXT_STATE = WRITE_WAIT;
                end
            end

            MREQ: NEXT_STATE = (AR_READY && AR_VALID)? REFILL : MREQ;

            REFILL: begin
                if(R_VALID && R_READY) begin
                    if(REFILL_CNT == 3'd7) NEXT_STATE = READ;     // Last word - complete
                    else NEXT_STATE = MREQ;     // More words - issue next AR
                end
                else NEXT_STATE = REFILL;       // Wait for R_VALID
            end

            READ: NEXT_STATE = (CPU_REQ || CPU_WR_EN)? CMP : IDLE;

            default: NEXT_STATE = IDLE;
        endcase
    end

endmodule
