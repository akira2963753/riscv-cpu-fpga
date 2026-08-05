/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    CHECKER.sv
* Project:      RISC-V CPU AXI4 Bus
* Module:       CHECKER
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
* Specification:
*   Arm IHI 0022 Issue L, AMBA AXI Protocol Specification.
*   Assertions cover the Valid-Ready transport and the implemented AXI4
*   memory-subordinate subset.
******************************************************************************/

`timescale 1ns/1ps

module CHECKER #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 32,
    parameter int ID_W = 4,
    parameter int BRAM_DEPTH = 256
) (
    input logic ACLK,
    input logic ARESETn,

    input logic [ID_W-1:0] AW_ID,
    input logic [ADDR_W-1:0] AW_ADDR,
    input logic [7:0] AW_LEN,
    input logic [2:0] AW_SIZE,
    input logic [1:0] AW_BURST,
    input logic AW_LOCK,
    input logic [3:0] AW_CACHE,
    input logic [2:0] AW_PROT,
    input logic [3:0] AW_QOS,
    input logic AW_VALID,
    input logic AW_READY,

    input logic [DATA_W-1:0] W_DATA,
    input logic [DATA_W/8-1:0] W_STRB,
    input logic W_LAST,
    input logic W_VALID,
    input logic W_READY,

    input logic [ID_W-1:0] B_ID,
    input logic [1:0] B_RESP,
    input logic B_VALID,
    input logic B_READY,

    input logic [ID_W-1:0] AR_ID,
    input logic [ADDR_W-1:0] AR_ADDR,
    input logic [7:0] AR_LEN,
    input logic [2:0] AR_SIZE,
    input logic [1:0] AR_BURST,
    input logic AR_LOCK,
    input logic [3:0] AR_CACHE,
    input logic [2:0] AR_PROT,
    input logic [3:0] AR_QOS,
    input logic AR_VALID,
    input logic AR_READY,

    input logic [ID_W-1:0] R_ID,
    input logic [DATA_W-1:0] R_DATA,
    input logic [1:0] R_RESP,
    input logic R_LAST,
    input logic R_VALID,
    input logic R_READY
);

    localparam int STRB_W = DATA_W / 8;
    localparam int BYTE_LSB = $clog2(STRB_W);
    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_EXOKAY = 2'b01;
    localparam logic [1:0] AXI_SLVERR = 2'b10;
    localparam logic [1:0] AXI_DECERR = 2'b11;
    localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [1:0] AXI_BURST_WRAP = 2'b10;
    localparam logic [1:0] AXI_BURST_RESERVED = 2'b11;
    localparam logic [ADDR_W:0] MEMORY_BYTES = BRAM_DEPTH * STRB_W;

    logic write_open;
    logic write_response_pending;
    logic [ID_W-1:0] write_id;
    logic [ADDR_W-1:0] write_addr;
    logic [7:0] write_len;
    logic [7:0] write_beat;
    logic [2:0] write_size;
    logic write_lock;
    logic [1:0] expected_b_resp;

    logic read_open;
    logic [ID_W-1:0] read_id;
    logic [ADDR_W-1:0] read_addr;
    logic [7:0] read_len;
    logic [7:0] read_beat;
    logic [2:0] read_size;
    logic read_lock;
    logic [1:0] read_request_resp;

    logic cov_single_write;
    logic cov_eight_beat_write;
    logic cov_eight_beat_read;
    logic cov_w_before_aw_ready;
    logic cov_b_backpressure;
    logic cov_r_backpressure;
    logic cov_concurrent_rw;
    logic cov_slverr;
    logic cov_decerr;

    logic aw_fire;
    logic w_fire;
    logic b_fire;
    logic ar_fire;
    logic r_fire;

    assign aw_fire = AW_VALID && AW_READY;
    assign w_fire = W_VALID && W_READY;
    assign b_fire = B_VALID && B_READY;
    assign ar_fire = AR_VALID && AR_READY;
    assign r_fire = R_VALID && R_READY;

    function automatic logic crosses_4kb(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        logic [12:0] transfer_bytes;
        logic [12:0] boundary_sum;
        begin
            transfer_bytes = ({5'b0, length} + 1'b1) << size;
            boundary_sum = {1'b0, address[11:0]} + transfer_bytes;
            crosses_4kb = (burst != AXI_BURST_FIXED) && (boundary_sum > 13'd4096);
        end
    endfunction

    function automatic logic legal_wrap_length(input logic [7:0] length);
        begin
            legal_wrap_length = (length == 8'd1) || (length == 8'd3) ||
                                (length == 8'd7) || (length == 8'd15);
        end
    endfunction

    function automatic logic [1:0] subset_request_response(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        begin
            if (burst != AXI_BURST_INCR) subset_request_response = AXI_SLVERR;
            else if (size != BYTE_LSB) subset_request_response = AXI_SLVERR;
            else if (address[BYTE_LSB-1:0] != '0) subset_request_response = AXI_SLVERR;
            else if (crosses_4kb(address, length, size, burst)) begin
                subset_request_response = AXI_SLVERR;
            end
            else subset_request_response = AXI_OKAY;
        end
    endfunction

    function automatic logic [1:0] expected_write_response(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        logic [1:0] request_resp;
        logic [ADDR_W:0] last_address;
        begin
            request_resp = subset_request_response(address, length, size, burst);
            last_address = {1'b0, address} + ({1'b0, length} << size);

            if (request_resp != AXI_OKAY) expected_write_response = request_resp;
            else if (last_address >= MEMORY_BYTES) expected_write_response = AXI_DECERR;
            else expected_write_response = AXI_OKAY;
        end
    endfunction

    function automatic logic [1:0] expected_read_response(
        input logic [1:0] request_resp,
        input logic [ADDR_W-1:0] address,
        input logic [7:0] beat,
        input logic [2:0] size
    );
        logic [ADDR_W:0] beat_address;
        begin
            beat_address = {1'b0, address} + ({1'b0, beat} << size);

            if (request_resp != AXI_OKAY) expected_read_response = request_resp;
            else if (beat_address >= MEMORY_BYTES) expected_read_response = AXI_DECERR;
            else expected_read_response = AXI_OKAY;
        end
    endfunction

    //=============================================================
    // ---------------- Transaction Scoreboard --------------------
    //=============================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            write_open <= 1'b0;
            write_response_pending <= 1'b0;
            write_id <= '0;
            write_addr <= '0;
            write_len <= '0;
            write_beat <= '0;
            write_size <= '0;
            write_lock <= 1'b0;
            expected_b_resp <= AXI_OKAY;
        end
        else begin
            if (aw_fire) begin
                write_open <= 1'b1;
                write_id <= AW_ID;
                write_addr <= AW_ADDR;
                write_len <= AW_LEN;
                write_beat <= '0;
                write_size <= AW_SIZE;
                write_lock <= AW_LOCK;
                expected_b_resp <= expected_write_response(
                    AW_ADDR, AW_LEN, AW_SIZE, AW_BURST
                );
            end

            if (w_fire && write_open) begin
                if (write_beat == write_len) begin
                    write_open <= 1'b0;
                    write_response_pending <= 1'b1;
                end
                else begin
                    write_beat <= write_beat + 1'b1;
                end
            end

            if (b_fire) write_response_pending <= 1'b0;
        end
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            read_open <= 1'b0;
            read_id <= '0;
            read_addr <= '0;
            read_len <= '0;
            read_beat <= '0;
            read_size <= '0;
            read_lock <= 1'b0;
            read_request_resp <= AXI_OKAY;
        end
        else begin
            if (ar_fire) begin
                read_open <= 1'b1;
                read_id <= AR_ID;
                read_addr <= AR_ADDR;
                read_len <= AR_LEN;
                read_beat <= '0;
                read_size <= AR_SIZE;
                read_lock <= AR_LOCK;
                read_request_resp <= subset_request_response(
                    AR_ADDR, AR_LEN, AR_SIZE, AR_BURST
                );
            end

            if (r_fire && read_open) begin
                if (read_beat == read_len) read_open <= 1'b0;
                else read_beat <= read_beat + 1'b1;
            end
        end
    end

    //=============================================================
    // --------------- Valid & Payload Stability -----------------
    //=============================================================
    property p_aw_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        AW_VALID && !AW_READY |=> AW_VALID &&
            $stable({AW_ID, AW_ADDR, AW_LEN, AW_SIZE, AW_BURST,
                AW_LOCK, AW_CACHE, AW_PROT, AW_QOS});
    endproperty

    property p_w_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        W_VALID && !W_READY |=> W_VALID &&
            $stable({W_DATA, W_STRB, W_LAST});
    endproperty

    property p_b_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID && !B_READY |=> B_VALID && $stable({B_ID, B_RESP});
    endproperty

    property p_ar_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        AR_VALID && !AR_READY |=> AR_VALID &&
            $stable({AR_ID, AR_ADDR, AR_LEN, AR_SIZE, AR_BURST,
                AR_LOCK, AR_CACHE, AR_PROT, AR_QOS});
    endproperty

    property p_r_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID && !R_READY |=> R_VALID &&
            $stable({R_ID, R_DATA, R_RESP, R_LAST});
    endproperty

    CHECK_AW_STABLE: assert property(p_aw_stable)
        else $fatal(1, "[ERROR] : AW payload changed before handshake");
    CHECK_W_STABLE: assert property(p_w_stable)
        else $fatal(1, "[ERROR] : W payload changed before handshake");
    CHECK_B_STABLE: assert property(p_b_stable)
        else $fatal(1, "[ERROR] : B payload changed before handshake");
    CHECK_AR_STABLE: assert property(p_ar_stable)
        else $fatal(1, "[ERROR] : AR payload changed before handshake");
    CHECK_R_STABLE: assert property(p_r_stable)
        else $fatal(1, "[ERROR] : R payload changed before handshake");

    //=============================================================
    // ----------------- Reset & Known Values ---------------------
    //=============================================================
    CHECK_RESET_VALID_LOW: assert property(
        @(posedge ACLK) !ARESETn |->
            (!AW_VALID && !W_VALID && !B_VALID && !AR_VALID && !R_VALID)
    ) else $fatal(1, "[ERROR] : VALID signal asserted during reset");

    CHECK_AW_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        AW_VALID |-> !$isunknown({AW_ID, AW_ADDR, AW_LEN, AW_SIZE, AW_BURST})
    ) else $fatal(1, "[ERROR] : Unknown value on valid AW channel");

    CHECK_W_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        W_VALID |-> !$isunknown({W_DATA, W_STRB, W_LAST})
    ) else $fatal(1, "[ERROR] : Unknown value on valid W channel");

    CHECK_B_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> !$isunknown({B_ID, B_RESP})
    ) else $fatal(1, "[ERROR] : Unknown value on valid B channel");

    CHECK_AR_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        AR_VALID |-> !$isunknown({AR_ID, AR_ADDR, AR_LEN, AR_SIZE, AR_BURST})
    ) else $fatal(1, "[ERROR] : Unknown value on valid AR channel");

    CHECK_R_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> !$isunknown({R_ID, R_DATA, R_RESP, R_LAST})
    ) else $fatal(1, "[ERROR] : Unknown value on valid R channel");

    //=============================================================
    // --------------- Request & Burst Legality ------------------
    //=============================================================
    CHECK_AW_BURST_ENCODING: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire |-> (AW_BURST != AXI_BURST_RESERVED)
    ) else $fatal(1, "[ERROR] : Reserved AWBURST encoding");

    CHECK_AR_BURST_ENCODING: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire |-> (AR_BURST != AXI_BURST_RESERVED)
    ) else $fatal(1, "[ERROR] : Reserved ARBURST encoding");

    CHECK_AW_SIZE: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire |-> (AW_SIZE <= BYTE_LSB)
    ) else $fatal(1, "[ERROR] : AWSIZE exceeds data bus width");

    CHECK_AR_SIZE: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire |-> (AR_SIZE <= BYTE_LSB)
    ) else $fatal(1, "[ERROR] : ARSIZE exceeds data bus width");

    CHECK_AW_4KB: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire |-> !crosses_4kb(AW_ADDR, AW_LEN, AW_SIZE, AW_BURST)
    ) else $fatal(1, "[ERROR] : Write transaction crosses 4KB boundary");

    CHECK_AR_4KB: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire |-> !crosses_4kb(AR_ADDR, AR_LEN, AR_SIZE, AR_BURST)
    ) else $fatal(1, "[ERROR] : Read transaction crosses 4KB boundary");

    CHECK_AW_WRAP_LENGTH: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire && (AW_BURST == AXI_BURST_WRAP) |-> legal_wrap_length(AW_LEN)
    ) else $fatal(1, "[ERROR] : Illegal WRAP write length");

    CHECK_AR_WRAP_LENGTH: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire && (AR_BURST == AXI_BURST_WRAP) |-> legal_wrap_length(AR_LEN)
    ) else $fatal(1, "[ERROR] : Illegal WRAP read length");

    CHECK_AW_FIXED_LENGTH: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire && (AW_BURST == AXI_BURST_FIXED) |-> (AW_LEN <= 8'd15)
    ) else $fatal(1, "[ERROR] : FIXED write length exceeds 16 transfers");

    CHECK_AR_FIXED_LENGTH: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire && (AR_BURST == AXI_BURST_FIXED) |-> (AR_LEN <= 8'd15)
    ) else $fatal(1, "[ERROR] : FIXED read length exceeds 16 transfers");

    //=============================================================
    // ------------- Channel Dependency & Ordering ---------------
    //=============================================================
    CHECK_SINGLE_AW: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        aw_fire |-> (!write_open && !write_response_pending)
    ) else $fatal(1, "[ERROR] : More than one outstanding write transaction");

    CHECK_W_AFTER_AW: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        w_fire |-> write_open
    ) else $fatal(1, "[ERROR] : Write data accepted without a write request");

    CHECK_WLAST: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        w_fire |-> (W_LAST == (write_beat == write_len))
    ) else $fatal(1, "[ERROR] : WLAST does not match AWLEN");

    CHECK_B_AFTER_LAST: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        w_fire && W_LAST |=> B_VALID
    ) else $fatal(1, "[ERROR] : BVALID did not follow the last write transfer");

    CHECK_B_DEPENDENCY: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> write_response_pending
    ) else $fatal(1, "[ERROR] : BVALID asserted before write completion");

    CHECK_B_ID: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> (B_ID == write_id)
    ) else $fatal(1, "[ERROR] : BID does not match AWID");

    CHECK_B_RESPONSE: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> (B_RESP == expected_b_resp)
    ) else $fatal(1, "[ERROR] : BRESP does not match request result");

    CHECK_B_EXOKAY: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID && !write_lock |-> (B_RESP != AXI_EXOKAY)
    ) else $fatal(1, "[ERROR] : EXOKAY used for a non-exclusive write");

    CHECK_SINGLE_AR: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        ar_fire |-> !read_open
    ) else $fatal(1, "[ERROR] : More than one outstanding read transaction");

    CHECK_R_AFTER_AR: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> read_open
    ) else $fatal(1, "[ERROR] : RVALID asserted without a read request");

    CHECK_RLAST: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> (R_LAST == (read_beat == read_len))
    ) else $fatal(1, "[ERROR] : RLAST does not match ARLEN");

    CHECK_R_ID: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> (R_ID == read_id)
    ) else $fatal(1, "[ERROR] : RID does not match ARID");

    CHECK_R_RESPONSE: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> (R_RESP == expected_read_response(
            read_request_resp, read_addr, read_beat, read_size
        ))
    ) else $fatal(1, "[ERROR] : RRESP does not match request result");

    CHECK_R_EXOKAY: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID && !read_lock |-> (R_RESP != AXI_EXOKAY)
    ) else $fatal(1, "[ERROR] : EXOKAY used for a non-exclusive read");

    //=============================================================
    // ---------------- Procedural Coverage -----------------------
    //=============================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            cov_single_write <= 1'b0;
            cov_eight_beat_write <= 1'b0;
            cov_eight_beat_read <= 1'b0;
            cov_w_before_aw_ready <= 1'b0;
            cov_b_backpressure <= 1'b0;
            cov_r_backpressure <= 1'b0;
            cov_concurrent_rw <= 1'b0;
            cov_slverr <= 1'b0;
            cov_decerr <= 1'b0;
        end
        else begin
            if (aw_fire && (AW_LEN == 8'd0)) cov_single_write <= 1'b1;
            if (aw_fire && (AW_LEN == 8'd7)) cov_eight_beat_write <= 1'b1;
            if (ar_fire && (AR_LEN == 8'd7)) cov_eight_beat_read <= 1'b1;
            if (W_VALID && !W_READY) cov_w_before_aw_ready <= 1'b1;
            if (B_VALID && !B_READY) cov_b_backpressure <= 1'b1;
            if (R_VALID && !R_READY) cov_r_backpressure <= 1'b1;
            if (write_open && read_open) cov_concurrent_rw <= 1'b1;
            if ((B_VALID && (B_RESP == AXI_SLVERR)) ||
                (R_VALID && (R_RESP == AXI_SLVERR))) cov_slverr <= 1'b1;
            if ((B_VALID && (B_RESP == AXI_DECERR)) ||
                (R_VALID && (R_RESP == AXI_DECERR))) cov_decerr <= 1'b1;
        end
    end

    final begin
        $display("CHECKER coverage: single=%0b w8=%0b r8=%0b w_wait=%0b b_stall=%0b",
            cov_single_write, cov_eight_beat_write, cov_eight_beat_read,
            cov_w_before_aw_ready, cov_b_backpressure);
        $display("CHECKER coverage: r_stall=%0b concurrent=%0b slverr=%0b decerr=%0b",
            cov_r_backpressure, cov_concurrent_rw, cov_slverr, cov_decerr);
    end

endmodule
