`include "SYSTEM_DEF.vh"

module I_Cache(
    input ACLK,
    input ARESETn,
    
    // CPU Fetch
    input CPU_REQ,
    input [`PC_WIDTH-1:0] CPU_REQ_ADDR,
    output CPU_REQ_VALID,
    output [`DATA_WIDTH-1:0] CPU_REQ_DATA,

    // Control
    output BUSY,

    // AXI Read Master Output (Slave Input)
    output reg AR_VALID,
    output reg R_READY,
    output reg [`PC_WIDTH-1:0] AR_ADDR,

    // AXI Read Master Input (Slave Output)
    input AR_READY,
    input R_VALID,
    input [`DATA_WIDTH-1:0] R_DATA
);

    // FSM
    localparam [2:0] IDLE = 3'd0, CMP = 3'd1, MREQ = 3'd2, REFILL = 3'd3, READ = 3'd4;
    reg [2:0] STATE, NEXT_STATE;

    // NOP instruction for default output
    localparam  NOP = 32'h00000013;         

    integer i,j;
     
    // Instruction Address : TAG | INDEX | WORD_OFFEST | 00
    wire [`TAG_WIDTH - 1 :0] TAG;
    wire [`INDEX_WIDTH - 1 :0] INDEX;
    wire [`OFFSET_WIDTH - 1 :0] OFFSET;
    wire [`WORD_OFFEST_WIDTH - 1 :0] WORD_OFFEST;

    assign TAG = CPU_REQ_ADDR[`PC_WIDTH - 1 : `PC_WIDTH - `TAG_WIDTH];
    assign INDEX = CPU_REQ_ADDR[`PC_WIDTH - `TAG_WIDTH - 1 : `PC_WIDTH - `TAG_WIDTH - `INDEX_WIDTH];
    assign OFFSET = CPU_REQ_ADDR[`OFFSET_WIDTH - 1 : 0];
    assign WORD_OFFEST = CPU_REQ_ADDR[`OFFSET_WIDTH - 1 : `OFFSET_WIDTH - `WORD_OFFEST_WIDTH];

    // Cache
    reg [`TAG_WIDTH - 1 :0] TAG_ARRAY [0:`WAY-1][0:`SET_NUM-1];
    reg [`DATA_WIDTH - 1 :0] DATA_ARRAY [0:`WAY-1][0:`SET_NUM-1][0:`BLOCK_WORD_SIZE-1];
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

    assign HIT0 = VALID_ARRAY[0][INDEX] && (TAG_ARRAY[0][INDEX] == TAG);
    assign HIT1 = VALID_ARRAY[1][INDEX] && (TAG_ARRAY[1][INDEX] == TAG);

    assign CACHE_HIT = HIT0 | HIT1;
    assign HIT_WAY = HIT1;
    assign EMPTY = !VALID_ARRAY[0][INDEX] | !VALID_ARRAY[1][INDEX];

    assign CPU_REQ_DATA = ((STATE==CMP && CACHE_HIT))? DATA_ARRAY[HIT_WAY][INDEX][WORD_OFFEST] :
                          (STATE==READ)? DATA_ARRAY[RESP_WAY][RESP_INDEX][RESP_WORD_OFFEST] : `NOP;
    assign CPU_REQ_VALID = (STATE==CMP && CACHE_HIT) || (STATE==READ);
    assign BUSY = (STATE!=READ) && !(STATE==CMP && CACHE_HIT);
    
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
        end
        else begin
            case(STATE)
                IDLE: begin
                    // Close AXI
                    AR_VALID <= 0;
                    R_READY <= 0;
                end
                CMP : begin
                    if(CACHE_HIT) begin  // Hit
                        RESP_WAY <= HIT_WAY;
                        RESP_INDEX <= INDEX;
                        RESP_WORD_OFFEST <= WORD_OFFEST;
                        LRU[INDEX] <= ~HIT_WAY;
                    end
                    else begin  // Miss
                        // Choose Victim
                        if(EMPTY) VICTIM_WAY <= !VALID_ARRAY[0][INDEX];
                        else VICTIM_WAY <= LRU[INDEX];

                        // Fix Miss
                        MISS_INDEX <= INDEX;
                        MISS_TAG <= TAG;
                        MISS_WORD_OFFEST <= WORD_OFFEST;

                        // Align AR_ADDR to block boundary
                        AR_ADDR <= {CPU_REQ_ADDR[`PC_WIDTH-1:`OFFSET_WIDTH], {`OFFSET_WIDTH{1'b0}}};
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
            endcase 
        end
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) STATE <= IDLE;
        else STATE <= NEXT_STATE;
    end

    always @(*) begin
        case(STATE)
            IDLE: NEXT_STATE = (CPU_REQ)? CMP : IDLE;
            CMP: NEXT_STATE = (CPU_REQ)? ((CACHE_HIT)? CMP : MREQ) : IDLE;
            MREQ: NEXT_STATE = (AR_READY && AR_VALID)? REFILL : MREQ;
            REFILL: begin
                if(R_VALID && R_READY) begin
                    if(REFILL_CNT == 3'd7) NEXT_STATE = READ;     // Last word - complete
                    else NEXT_STATE = MREQ;     // More words - issue next AR
                end
                else NEXT_STATE = REFILL;       // Wait for R_VALID
            end
            READ: NEXT_STATE = (CPU_REQ)? CMP : IDLE;
            default: NEXT_STATE = IDLE;
        endcase
    end


endmodule
