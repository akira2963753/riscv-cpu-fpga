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
*   Assertions check channel handshakes, transaction ordering, and responses.
******************************************************************************/

import AXI4_PKG::*;

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
    input resp_type B_RESP,
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
    input resp_type R_RESP,
    input logic R_LAST,
    input logic R_VALID,
    input logic R_READY
);

    logic write_open;
    logic write_response_pending;
    logic [ID_W-1:0] write_id;
    logic [7:0] write_len;
    logic [7:0] write_beat;
    logic write_lock;

    logic read_open;
    logic [ID_W-1:0] read_id;
    logic [7:0] read_len;
    logic [7:0] read_beat;
    logic read_lock;

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

    //=============================================================
    // ---------------- Transaction Tracking ---------------------
    //=============================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            write_open             <= 1'b0;
            write_response_pending <= 1'b0;
            write_id               <= '0;
            write_len              <= '0;
            write_beat             <= '0;
            write_lock             <= 1'b0;
        end
        else begin
            if (aw_fire) begin
                write_open <= 1'b1;
                write_id   <= AW_ID;
                write_len  <= AW_LEN;
                write_beat <= '0;
                write_lock <= AW_LOCK;
            end

            if (w_fire && write_open) begin
                if (write_beat == write_len) begin
                    write_open             <= 1'b0;
                    write_response_pending <= 1'b1;
                end
                else begin
                    write_beat <= write_beat + 1'b1;
                end
            end

            if (b_fire) begin
                write_response_pending <= 1'b0;
            end
        end
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            read_open <= 1'b0;
            read_id   <= '0;
            read_len  <= '0;
            read_beat <= '0;
            read_lock <= 1'b0;
        end
        else begin
            if (ar_fire) begin
                read_open <= 1'b1;
                read_id   <= AR_ID;
                read_len  <= AR_LEN;
                read_beat <= '0;
                read_lock <= AR_LOCK;
            end

            if (r_fire && read_open) begin
                if (read_beat == read_len) begin
                    read_open <= 1'b0;
                end
                else begin
                    read_beat <= read_beat + 1'b1;
                end
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
        AW_VALID |-> !$isunknown({AW_ID, AW_ADDR, AW_LEN, AW_SIZE, AW_BURST,
            AW_LOCK, AW_CACHE, AW_PROT, AW_QOS})
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
        AR_VALID |-> !$isunknown({AR_ID, AR_ADDR, AR_LEN, AR_SIZE, AR_BURST,
            AR_LOCK, AR_CACHE, AR_PROT, AR_QOS})
    ) else $fatal(1, "[ERROR] : Unknown value on valid AR channel");

    CHECK_R_KNOWN: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID |-> !$isunknown({R_ID, R_DATA, R_RESP, R_LAST})
    ) else $fatal(1, "[ERROR] : Unknown value on valid R channel");

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

    CHECK_B_DEPENDENCY: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> write_response_pending
    ) else $fatal(1, "[ERROR] : BVALID asserted before write completion");

    CHECK_B_ID: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        B_VALID |-> (B_ID == write_id)
    ) else $fatal(1, "[ERROR] : BID does not match AWID");

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

    CHECK_R_EXOKAY: assert property(
        @(posedge ACLK) disable iff (!ARESETn)
        R_VALID && !read_lock |-> (R_RESP != AXI_EXOKAY)
    ) else $fatal(1, "[ERROR] : EXOKAY used for a non-exclusive read");

endmodule
