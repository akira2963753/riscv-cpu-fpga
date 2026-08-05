/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    AXI4_Bus.sv
* Project:      RISC-V CPU AXI4 Bus
* Module:       AXI4_Bus
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
* Description:
*   AXI4 slave to single-port synchronous BRAM bridge. The implementation
*   supports one outstanding read burst and one outstanding write burst.
*   Only aligned, full-width INCR bursts are supported.
******************************************************************************/

`timescale 1ns/1ps

module AXI4_Bus #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 32,
    parameter int ID_W = 4,
    parameter int BRAM_DEPTH = 1024,
    parameter int BRAM_ADDR_W = $clog2(BRAM_DEPTH)
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
    output logic AW_READY,

    input logic [DATA_W-1:0] W_DATA,
    input logic [DATA_W/8-1:0] W_STRB,
    input logic W_LAST,
    input logic W_VALID,
    output logic W_READY,

    output logic [ID_W-1:0] B_ID,
    output logic [1:0] B_RESP,
    output logic B_VALID,
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
    output logic AR_READY,

    output logic [ID_W-1:0] R_ID,
    output logic [DATA_W-1:0] R_DATA,
    output logic [1:0] R_RESP,
    output logic R_LAST,
    output logic R_VALID,
    input logic R_READY,

    output logic SLAVE_EN,
    output logic [DATA_W/8-1:0] SLAVE_WE,
    output logic [BRAM_ADDR_W-1:0] SLAVE_ADDR,
    output logic [DATA_W-1:0] SLAVE_DIN,
    input logic [DATA_W-1:0] SLAVE_DOUT
);

    localparam int STRB_W = DATA_W / 8;
    localparam int BYTE_LSB = $clog2(STRB_W);
    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;
    localparam logic [1:0] AXI_DECERR = 2'b11;
    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [ADDR_W:0] MEMORY_BYTES = BRAM_DEPTH * STRB_W;

    logic write_active;
    logic [ID_W-1:0] write_id;
    logic [ADDR_W-1:0] write_addr;
    logic [7:0] write_len;
    logic [7:0] write_beat;
    logic [2:0] write_size;
    logic [1:0] write_req_resp;

    logic read_active;
    logic [ID_W-1:0] read_id;
    logic [ADDR_W-1:0] read_addr;
    logic [7:0] read_len;
    logic [7:0] read_beat;
    logic [2:0] read_size;
    logic [1:0] read_req_resp;

    logic read_pending;
    logic [ID_W-1:0] read_pending_id;
    logic [1:0] read_pending_resp;
    logic read_pending_last;

    logic write_fire;
    logic write_expected_last;
    logic [1:0] write_beat_resp;
    logic [1:0] write_last_resp;
    logic read_capture;
    logic read_issue;
    logic read_issue_last;
    logic [1:0] read_issue_resp;

    function automatic logic [1:0] request_response(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        logic [ADDR_W:0] transfer_bytes;
        logic [12:0] boundary_sum;
        begin
            transfer_bytes = ({1'b0, length} + 1'b1) << size;
            boundary_sum = {1'b0, address[11:0]} + transfer_bytes[12:0];

            if(burst != AXI_BURST_INCR) request_response = AXI_SLVERR;
            else if(size != BYTE_LSB) request_response = AXI_SLVERR;
            else if(address[BYTE_LSB-1:0] != '0) request_response = AXI_SLVERR;
            else if(boundary_sum > 13'd4096) request_response = AXI_SLVERR;
            else request_response = AXI_OKAY;
        end
    endfunction

    function automatic logic [1:0] beat_response(
        input logic [1:0] request_resp,
        input logic [ADDR_W-1:0] address
    );
        begin
            if(request_resp != AXI_OKAY) beat_response = request_resp;
            else if({1'b0, address} >= MEMORY_BYTES) beat_response = AXI_DECERR;
            else beat_response = AXI_OKAY;
        end
    endfunction

    function automatic logic [1:0] merge_response(
        input logic [1:0] accumulated,
        input logic [1:0] current
    );
        begin
            if((accumulated == AXI_DECERR) || (current == AXI_DECERR))  merge_response = AXI_DECERR;
            else if((accumulated == AXI_SLVERR) || (current == AXI_SLVERR)) merge_response = AXI_SLVERR;
            else merge_response = AXI_OKAY;
        end
    endfunction

    assign AW_READY = !write_active && !B_VALID;
    assign W_READY = write_active && !B_VALID;
    assign AR_READY = !read_active && !read_pending && !R_VALID;

    assign write_fire = W_VALID && W_READY;
    assign write_expected_last = (write_beat == write_len);
    assign write_beat_resp = beat_response(write_req_resp, write_addr);
    assign write_last_resp = merge_response(
        write_beat_resp,
        (W_LAST == write_expected_last) ? AXI_OKAY : AXI_SLVERR
    );

    assign read_capture = read_pending && (!R_VALID || R_READY);
    assign read_issue = read_active && (!read_pending || read_capture) &&
                        (!R_VALID || R_READY) && !write_fire;
    assign read_issue_last = (read_beat == read_len);
    assign read_issue_resp = beat_response(read_req_resp, read_addr);

    always_comb begin
        SLAVE_EN = 1'b0;
        SLAVE_WE = '0;
        SLAVE_ADDR = '0;
        SLAVE_DIN = '0;

        if(write_fire) begin
            SLAVE_EN = (write_beat_resp == AXI_OKAY);
            SLAVE_WE = (write_beat_resp == AXI_OKAY) ? W_STRB : '0;
            SLAVE_ADDR = write_addr[BRAM_ADDR_W+BYTE_LSB-1:BYTE_LSB];
            SLAVE_DIN = W_DATA;
        end
        else if(read_issue) begin
            SLAVE_EN = (read_issue_resp == AXI_OKAY);
            SLAVE_ADDR = read_addr[BRAM_ADDR_W+BYTE_LSB-1:BYTE_LSB];
        end
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            write_active <= 1'b0;
            write_id <= '0;
            write_addr <= '0;
            write_len <= '0;
            write_beat <= '0;
            write_size <= '0;
            write_req_resp <= AXI_OKAY;
            B_ID <= '0;
            B_RESP <= AXI_OKAY;
            B_VALID <= 1'b0;
        end
        else begin
            if(B_VALID && B_READY) B_VALID <= 1'b0;

            if(AW_VALID && AW_READY) begin
  				write_active <= 1'b1;
                write_id <= AW_ID;
                write_addr <= AW_ADDR;
                write_len <= AW_LEN;
                write_beat <= '0;
                write_size <= AW_SIZE;
                write_req_resp <= request_response(AW_ADDR, AW_LEN, AW_SIZE, AW_BURST);
            end

            if(write_fire) begin
                write_req_resp <= merge_response(write_req_resp, write_last_resp);
                if(write_expected_last) begin
                    write_active <= 1'b0;
                    B_ID <= write_id;
                    B_RESP <= merge_response(write_req_resp, write_last_resp);
                    B_VALID <= 1'b1;
                end
                else begin
                    write_addr <= write_addr + ({{(ADDR_W-1){1'b0}}, 1'b1} << write_size);
                    write_beat <= write_beat + 1'b1;
                end
            end
        end
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if(!ARESETn) begin
            read_active <= 1'b0;
            read_id <= '0;
            read_addr <= '0;
            read_len <= '0;
            read_beat <= '0;
            read_size <= '0;
            read_req_resp <= AXI_OKAY;
            read_pending <= 1'b0;
            read_pending_id <= '0;
            read_pending_resp <= AXI_OKAY;
            read_pending_last <= 1'b0;
            R_ID <= '0;
            R_DATA <= '0;
            R_RESP <= AXI_OKAY;
            R_LAST <= 1'b0;
            R_VALID <= 1'b0;
        end
        else begin
            if(R_VALID && R_READY) begin
                R_VALID <= 1'b0;
                R_LAST <= 1'b0;
            end
            if(read_capture) read_pending <= 1'b0;

            if(AR_VALID && AR_READY) begin
                read_active <= 1'b1;
                read_id <= AR_ID;
                read_addr <= AR_ADDR;
                read_len <= AR_LEN;
                read_beat <= '0;
                read_size <= AR_SIZE;
                read_req_resp <= request_response(AR_ADDR, AR_LEN, AR_SIZE, AR_BURST);
            end

            if(read_capture) begin
                R_ID <= read_pending_id;
                R_DATA <= (read_pending_resp == AXI_OKAY) ? SLAVE_DOUT : '0;
                R_RESP <= read_pending_resp;
                R_LAST <= read_pending_last;
                R_VALID <= 1'b1;
            end

            if(read_issue) begin
                read_pending <= 1'b1;
                read_pending_id <= read_id;
                read_pending_resp <= read_issue_resp;
                read_pending_last <= read_issue_last;

                if(read_issue_last) begin
                    read_active <= 1'b0;
                end
                else begin
                    read_addr <= read_addr + ({{(ADDR_W-1){1'b0}}, 1'b1} << read_size);
                    read_beat <= read_beat + 1'b1;
                end
            end
        end
    end

    logic unused_attributes;
    assign unused_attributes = AW_LOCK ^ AR_LOCK ^ ^AW_CACHE ^ ^AW_PROT ^
                               ^AW_QOS ^ ^AR_CACHE ^ ^AR_PROT ^ ^AR_QOS;

endmodule
