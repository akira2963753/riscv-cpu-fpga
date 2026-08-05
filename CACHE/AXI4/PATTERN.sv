/******************************************************************************
* Copyright (C) 2026 Marco
*
* File Name:    PATTERN.sv
* Project:      RISC-V CPU AXI4 Bus
* Module:       PATTERN
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439
* Tool:         Vivado 2025.1
*
******************************************************************************/

`timescale 1ns/1ps
`define CLK_PERIOD 10.0
`define TIMEOUT 200000

module PATTERN #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 32,
    parameter int ID_W = 4,
    parameter int BRAM_DEPTH = 256
) (
    output logic ACLK,
    output logic ARESETn,

    output logic [ID_W-1:0] AW_ID,
    output logic [ADDR_W-1:0] AW_ADDR,
    output logic [7:0] AW_LEN,
    output logic [2:0] AW_SIZE,
    output logic [1:0] AW_BURST,
    output logic AW_LOCK,
    output logic [3:0] AW_CACHE,
    output logic [2:0] AW_PROT,
    output logic [3:0] AW_QOS,
    output logic AW_VALID,
    input logic AW_READY,

    output logic [DATA_W-1:0] W_DATA,
    output logic [DATA_W/8-1:0] W_STRB,
    output logic W_LAST,
    output logic W_VALID,
    input logic W_READY,

    input logic [ID_W-1:0] B_ID,
    input logic [1:0] B_RESP,
    input logic B_VALID,
    output logic B_READY,

    output logic [ID_W-1:0] AR_ID,
    output logic [ADDR_W-1:0] AR_ADDR,
    output logic [7:0] AR_LEN,
    output logic [2:0] AR_SIZE,
    output logic [1:0] AR_BURST,
    output logic AR_LOCK,
    output logic [3:0] AR_CACHE,
    output logic [2:0] AR_PROT,
    output logic [3:0] AR_QOS,
    output logic AR_VALID,
    input logic AR_READY,

    input logic [ID_W-1:0] R_ID,
    input logic [DATA_W-1:0] R_DATA,
    input logic [1:0] R_RESP,
    input logic R_LAST,
    input logic R_VALID,
    output logic R_READY
);

    localparam int STRB_W = DATA_W / 8;
    localparam int BYTE_LSB = $clog2(STRB_W);
    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;
    localparam logic [1:0] AXI_DECERR = 2'b11;
    localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [ID_W-1:0] WRITE_ID = 4'h5;
    localparam logic [ID_W-1:0] READ_ID = 4'ha;

    typedef enum int {
        PHASE_SINGLE,
        PHASE_BURST,
        PHASE_STROBE,
        PHASE_BACKPRESSURE,
        PHASE_ERROR,
        DONE
    } phase_type;

    phase_type veri_phase;
    logic [DATA_W-1:0] golden_mem [0:BRAM_DEPTH-1];

    //=============================================================
    // ------------------- Clock & Reset --------------------------
    //=============================================================
    initial ACLK = 1'b0;
    always #(`CLK_PERIOD/2.0) ACLK = ~ACLK;

    task automatic drive_idle();
        AW_ID = '0;
        AW_ADDR = '0;
        AW_LEN = '0;
        AW_SIZE = BYTE_LSB;
        AW_BURST = AXI_BURST_INCR;
        AW_LOCK = 1'b0;
        AW_CACHE = '0;
        AW_PROT = '0;
        AW_QOS = '0;
        AW_VALID = 1'b0;
        W_DATA = '0;
        W_STRB = '0;
        W_LAST = 1'b0;
        W_VALID = 1'b0;
        B_READY = 1'b0;
        AR_ID = '0;
        AR_ADDR = '0;
        AR_LEN = '0;
        AR_SIZE = BYTE_LSB;
        AR_BURST = AXI_BURST_INCR;
        AR_LOCK = 1'b0;
        AR_CACHE = '0;
        AR_PROT = '0;
        AR_QOS = '0;
        AR_VALID = 1'b0;
        R_READY = 1'b0;
    endtask

    task automatic reset_dut();
        ARESETn = 1'b1;
        drive_idle();
        for (int idx = 0; idx < BRAM_DEPTH; idx++) golden_mem[idx] = '0;
        repeat(2) @(negedge ACLK);
        ARESETn = ~ARESETn;
        repeat(3) @(negedge ACLK);
        ARESETn = ~ARESETn;
        @(negedge ACLK);
    endtask

    //=============================================================
    // -------------------- AXI Write Tasks -----------------------
    //=============================================================
    task automatic send_aw(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst,
        input int delay_cycles
    );
        repeat(delay_cycles) @(negedge ACLK);
        @(negedge ACLK);
        AW_ID = WRITE_ID;
        AW_ADDR = address;
        AW_LEN = length;
        AW_SIZE = size;
        AW_BURST = burst;
        AW_VALID = 1'b1;

        while (!AW_READY) @(negedge ACLK);
        @(negedge ACLK);
        AW_VALID = 1'b0;
    endtask

    task automatic send_w(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [DATA_W-1:0] data_base,
        input logic [STRB_W-1:0] strobe,
        input logic wrong_last,
        input logic update_golden,
        input int delay_cycles
    );
        logic [DATA_W-1:0] beat_data;
        int word_addr;

        repeat(delay_cycles) @(negedge ACLK);
        @(negedge ACLK);
        for (int beat = 0; beat <= length; beat++) begin
            beat_data = data_base + (beat * 32'h0101_0101);
            W_DATA = beat_data;
            W_STRB = strobe;
            W_LAST = (beat == length) ^ wrong_last;
            W_VALID = 1'b1;

            while (!W_READY) @(negedge ACLK);
            @(negedge ACLK);

            if (update_golden) begin
                word_addr = (address >> BYTE_LSB) + beat;
                for (int byte_idx = 0; byte_idx < STRB_W; byte_idx++) begin
                    if (strobe[byte_idx]) begin
                        golden_mem[word_addr][byte_idx*8 +: 8] =
                            beat_data[byte_idx*8 +: 8];
                    end
                end
            end
        end

        W_VALID = 1'b0;
        W_LAST = 1'b0;
        W_STRB = '0;
    endtask

    task automatic wait_b(
        input logic [1:0] expected_resp,
        input int stall_cycles
    );
        while (!B_VALID) @(negedge ACLK);

        if (B_ID !== WRITE_ID) begin
            $fatal(1, "[ERROR] : BID mismatch. Expected=%0h Actual=%0h", WRITE_ID, B_ID);
        end
        if (B_RESP !== expected_resp) begin
            $fatal(1, "[ERROR] : BRESP mismatch. Expected=%0h Actual=%0h", expected_resp, B_RESP);
        end

        repeat(stall_cycles) @(negedge ACLK);
        B_READY = 1'b1;
        @(negedge ACLK);
        B_READY = 1'b0;
    endtask

    task automatic axi_write(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [DATA_W-1:0] data_base,
        input logic [STRB_W-1:0] strobe,
        input int channel_order,
        input int b_stall_cycles,
        input logic [2:0] size,
        input logic [1:0] burst,
        input logic wrong_last,
        input logic update_golden,
        input logic [1:0] expected_resp
    );
        int aw_delay;
        int w_delay;

        aw_delay = (channel_order == 2) ? 3 : 0;
        w_delay = (channel_order == 0) ? 3 : 0;

        fork
            send_aw(address, length, size, burst, aw_delay);
            send_w(address, length, data_base, strobe, wrong_last, update_golden, w_delay);
        join

        wait_b(expected_resp, b_stall_cycles);
    endtask

    //=============================================================
    // --------------------- AXI Read Tasks -----------------------
    //=============================================================
    task automatic send_ar(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        @(negedge ACLK);
        AR_ID = READ_ID;
        AR_ADDR = address;
        AR_LEN = length;
        AR_SIZE = size;
        AR_BURST = burst;
        AR_VALID = 1'b1;

        while (!AR_READY) @(negedge ACLK);
        @(negedge ACLK);
        AR_VALID = 1'b0;
    endtask

    task automatic receive_r(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [1:0] expected_resp,
        input logic apply_backpressure
    );
        logic [DATA_W-1:0] expected_data;
        int beat;
        int cycle_count;
        int word_addr;

        beat = 0;
        cycle_count = 0;
        while (beat <= length) begin
            @(negedge ACLK);
            cycle_count++;
            R_READY = apply_backpressure ? ((cycle_count % 3) != 1) : 1'b1;

            if (R_VALID && R_READY) begin
                word_addr = (address >> BYTE_LSB) + beat;
                expected_data = (expected_resp == AXI_OKAY) ? golden_mem[word_addr] : '0;

                if (R_ID !== READ_ID) begin
                    $fatal(1, "[ERROR] : RID mismatch at beat %0d", beat);
                end
                if (R_RESP !== expected_resp) begin
                    $fatal(1, "[ERROR] : RRESP mismatch at beat %0d. Expected=%0h Actual=%0h",
                        beat, expected_resp, R_RESP);
                end
                if (R_DATA !== expected_data) begin
                    $fatal(1, "[ERROR] : RDATA mismatch at beat %0d. Expected=%08h Actual=%08h",
                        beat, expected_data, R_DATA);
                end
                if (R_LAST !== (beat == length)) begin
                    $fatal(1, "[ERROR] : RLAST mismatch at beat %0d", beat);
                end

                beat++;
            end

            if (cycle_count > 2000) begin
                $fatal(1, "[ERROR] : Read response timeout");
            end
        end

        @(negedge ACLK);
        R_READY = 1'b0;
    endtask

    task automatic axi_read(
        input logic [ADDR_W-1:0] address,
        input logic [7:0] length,
        input logic [2:0] size,
        input logic [1:0] burst,
        input logic [1:0] expected_resp,
        input logic apply_backpressure
    );
        fork
            send_ar(address, length, size, burst);
            receive_r(address, length, expected_resp, apply_backpressure);
        join
    endtask

    //=============================================================
    // ---------------------- Main Flow ---------------------------
    //=============================================================
    initial begin
        veri_phase = PHASE_SINGLE;
        reset_dut();

        veri_phase = PHASE_SINGLE;
        axi_write(32'h0000_0000, 8'd0, 32'h1122_3344, 4'b1111,
            0, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_write(32'h0000_0004, 8'd0, 32'h5566_7788, 4'b1111,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_write(32'h0000_0008, 8'd0, 32'h99aa_bbcc, 4'b1111,
            2, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_read(32'h0000_0000, 8'd2, BYTE_LSB, AXI_BURST_INCR, AXI_OKAY, 1'b0);
        $display("Phase 1 Pass: single-beat and AW/W ordering.");

        veri_phase = PHASE_BURST;
        axi_write(32'h0000_0040, 8'd3, 32'h1000_0000, 4'b1111,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_write(32'h0000_0080, 8'd7, 32'h2000_0000, 4'b1111,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_read(32'h0000_0040, 8'd3, BYTE_LSB, AXI_BURST_INCR, AXI_OKAY, 1'b0);
        axi_read(32'h0000_0080, 8'd7, BYTE_LSB, AXI_BURST_INCR, AXI_OKAY, 1'b0);
        $display("Phase 2 Pass: 4-beat and 8-beat INCR bursts.");

        veri_phase = PHASE_STROBE;
        axi_write(32'h0000_00c0, 8'd0, 32'ha5a5_5a5a, 4'b1111,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_write(32'h0000_00c0, 8'd0, 32'h1234_beef, 4'b0011,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_write(32'h0000_00c0, 8'd0, 32'hffff_ffff, 4'b0000,
            1, 0, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        axi_read(32'h0000_00c0, 8'd0, BYTE_LSB, AXI_BURST_INCR, AXI_OKAY, 1'b0);
        $display("Phase 3 Pass: partial and zero-strobe writes.");

        veri_phase = PHASE_BACKPRESSURE;
        axi_write(32'h0000_0100, 8'd7, 32'h3000_0000, 4'b1111,
            2, 5, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        fork
            axi_read(32'h0000_0100, 8'd7, BYTE_LSB,
                AXI_BURST_INCR, AXI_OKAY, 1'b1);
            axi_write(32'h0000_0180, 8'd7, 32'h3500_0000, 4'b1111,
                1, 3, BYTE_LSB, AXI_BURST_INCR, 1'b0, 1'b1, AXI_OKAY);
        join
        axi_read(32'h0000_0180, 8'd7, BYTE_LSB, AXI_BURST_INCR, AXI_OKAY, 1'b1);
        $display("Phase 4 Pass: backpressure and concurrent read/write.");

        veri_phase = PHASE_ERROR;
        axi_read(32'h0000_0002, 8'd0, BYTE_LSB, AXI_BURST_INCR, AXI_SLVERR, 1'b0);
        axi_read(BRAM_DEPTH * STRB_W, 8'd0, BYTE_LSB,
            AXI_BURST_INCR, AXI_DECERR, 1'b0);
        axi_read(32'h0000_0020, 8'd1, BYTE_LSB,
            AXI_BURST_FIXED, AXI_SLVERR, 1'b1);
        $display("Phase 5 Pass: SLVERR and DECERR checks.");

        veri_phase = DONE;
        repeat(3) @(negedge ACLK);
        $display("===============================================");
        $display("                  TEST PASS                    ");
        $display("===============================================");
        $finish;
    end

    initial begin
        #(`TIMEOUT);
        $display("AW: valid=%0b ready=%0b addr=%08h len=%0d", AW_VALID, AW_READY, AW_ADDR, AW_LEN);
        $display("W : valid=%0b ready=%0b data=%08h last=%0b", W_VALID, W_READY, W_DATA, W_LAST);
        $display("B : valid=%0b ready=%0b id=%0h resp=%0h", B_VALID, B_READY, B_ID, B_RESP);
        $display("AR: valid=%0b ready=%0b addr=%08h len=%0d", AR_VALID, AR_READY, AR_ADDR, AR_LEN);
        $display("R : valid=%0b ready=%0b data=%08h last=%0b resp=%0h", R_VALID, R_READY, R_DATA, R_LAST, R_RESP);
        $fatal(1, "[ERROR] : Simulation timeout in phase %0d", veri_phase);
    end

endmodule
