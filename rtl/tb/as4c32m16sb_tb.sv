// SDRAM chip testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module as4c32m16sb_tb;

initial begin
    $timeformat(-6, 0, " us", 1);

    $dumpfile("as4c32m16sb_tb.vcd");
    $dumpvars();
end

//////////////////////////////////////////////////////////////////////
// Memory

logic [12:0] a;
logic [1:0]  ba;
wire  [15:0] dq;
logic [15:0] dqi;
logic        dqml;
logic        dqmh;
logic        ncs;
logic        ncas;
logic        nras;
logic        nwe;
logic        clk;
logic        cke;

initial begin
    a = 'X;
    ba = 'X;
    dqi = 'Z;
    dqml = '1;
    dqmh = '1;
    ncs = '1;
    ncas = '1;
    nras = '1;
    nwe = '1;
    cke = '0;
    clk = 1;
end

assign dq = dqi;

// Clock rate is maximum for 7 ns SDRAM
as4c32m16sb #(.CLK_MHZ(142.8571428)) dut
   (
    .DQ(dq),
    .A(a),
    .DQML(dqml),
    .DQMH(dqmh),
    .BA(ba),
    .nCS(ncs),
    .nWE(nwe),
    .nRAS(nras),
    .nCAS(ncas),
    .CLK(clk),
    .CKE(cke)
    );

function [1:0] addr_to_bank(input [26:0] a);
	addr_to_bank = a[24:23];
endfunction

function [12:0] addr_to_row(input [26:0] a);
	addr_to_row = a[22:10];
endfunction

function [9:0] addr_to_col(input [26:0] a);
	addr_to_col = {a[25], a[9:1]};
endfunction

task sdram_read(input [26:0] addr, output [15:0] d);
    dut.read(addr_to_bank(addr),
             addr_to_row(addr),
             addr_to_col(addr),
             d);
endtask

task sdram_write(input [26:0] addr, input [15:0] d);
    dut.write(addr_to_bank(addr),
              addr_to_row(addr),
              addr_to_col(addr),
              d);
endtask

//////////////////////////////////////////////////////////////////////
// Bus tests

// Cycle times for maximum clk rate
localparam trc_min  = 9;
localparam trrd_min = 2;
localparam trcd_min = 3;
localparam trp_min  = 3;
localparam tras_min = 6;

localparam CMD_NOP             = 3'b111;
localparam CMD_BURST_TERMINATE = 3'b110;
localparam CMD_READ            = 3'b101;
localparam CMD_WRITE           = 3'b100;
localparam CMD_ACTIVE          = 3'b011;
localparam CMD_PRECHARGE       = 3'b010;
localparam CMD_AUTO_REFRESH    = 3'b001;
localparam CMD_LOAD_MODE       = 3'b000;

localparam BURST_LENGTH        = 2;
localparam BURST_CODE          = (BURST_LENGTH == 8) ? 3'b011 : (BURST_LENGTH == 4) ? 3'b010 : (BURST_LENGTH == 2) ? 3'b001 : 3'b000;  // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE         = 1'b0;     // 0=sequential, 1=interleaved
localparam CAS_LATENCY         = 3'd2;     // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE             = 2'b00;    // only 00 (standard operation) allowed
localparam NO_WRITE_BURST      = 1'b1;     // 0= write burst enabled, 1=only single access write
localparam MODE                = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_CODE};

task cmd(bit [2:0] cmd, int wait_clks);
    {nras, ncas, nwe} <= cmd;
    repeat (1) @(posedge clk) ;
    a <= '0;
    ba <= '0;
    {nras, ncas, nwe} <= CMD_NOP;
    repeat (wait_clks - 1) @(posedge clk) ;
endtask

task intertest_pause;
    // Some NOPs for spacing
    repeat (5) @(posedge clk) ;
endtask

task power_up;
    repeat (10) @(posedge clk) ; // min. 200us on real HW
    cke <= '1;
    repeat (2) @(posedge clk) ;

    // Precharge all banks
    ncs <= 1'b0;
    a <= 0;
    a[10] <= 1;
    cmd(CMD_PRECHARGE, trp_min);

    // Load mode
    a <= MODE;
    ba <= '0;
    cmd(CMD_LOAD_MODE, 2);

    // Two auto-refresh cycles
    repeat (2)
        cmd(CMD_AUTO_REFRESH, trc_min);

    intertest_pause();
endtask

task test_read_auto_tras_min;
    // This only works when BURST_LENGTH == 1.
    repeat (2) begin
        // Activate one bank
        ba <= 0;
        a <= 0;
        cmd(CMD_ACTIVE, trcd_min);

        // Read w/ pre-charge
        a[11] <= 0;
        a[10] <= 1; // auto-precharge
        a[9:0] <= 0;
        cmd(CMD_READ, tras_min - trcd_min);

        cmd(CMD_NOP, trc_min - tras_min);
    end

    intertest_pause();
endtask

task test_read_tras_min;
    // This only works when BURST_LENGTH == 1.
    repeat (2) begin
        // Activate one bank
        ba <= 0;
        a <= 0;
        cmd(CMD_ACTIVE, trcd_min);

        // Read
        a[11] <= 0;
        a[10] <= 0; // no auto-precharge
        a[9:0] <= 0;
        cmd(CMD_READ, tras_min - trcd_min);

        // Precharge
        a <= 0;
        a[10] <= 0; // one bank
        cmd(CMD_PRECHARGE, trp_min);
    end

    intertest_pause();
endtask

task test_fast_activate;
    // Activate all banks as quickly as possible
    for (int i = 0; i < 4; i++) begin
        ba <= i[1:0];
        a <= 0;
        cmd(CMD_ACTIVE, trrd_min);
    end

    // Wait tras from last bank active
    repeat (tras_min - trrd_min) @(posedge clk) ;

    // Precharge all banks
    a <= 0;
    a[10] <= 1;
    cmd(CMD_PRECHARGE, trp_min);

    intertest_pause();
endtask

task automatic test_interleaved_read_sub(input bit [1:0] bank, input int wait_clk);
bit [26:0] addr;
bit [31:0] data;
    addr = 0;
    addr[24:23] = bank;
    addr[18:17] = bank;
    addr[5:4] = bank;
    data[31:0] = {{8{bank}}, {8{~bank}}};
    sdram_write(addr, data[15:0]);
    sdram_write(addr+2, data[31:16]);

    repeat (wait_clk) @(posedge clk) ;

    ba <= addr_to_bank(addr);
    a[11:0] <= addr_to_row(addr);
    cmd(CMD_ACTIVE, CAS_LATENCY * 4);

    ba <= addr_to_bank(addr);
    a[11] <= 0;
    a[10] <= 1; // auto-precharge
    a[9:0] <= addr_to_col(addr);
    cmd(CMD_READ, CAS_LATENCY);

    @(posedge clk) ;
    assert(dq === data[15:0]);
    @(posedge clk) ;
    assert(dq === data[31:16]);

    repeat (CAS_LATENCY * 3 - 2) @(posedge clk) ;
endtask

task test_interleaved_read;
    dqml <= '0;
    dqmh <= '0;
    fork
        test_interleaved_read_sub(2'b00, 0);
        test_interleaved_read_sub(2'b01, 2);
        test_interleaved_read_sub(2'b10, 4);
        test_interleaved_read_sub(2'b11, 6);
    join
    dqml <= '1;
    dqmh <= '1;

    intertest_pause();
endtask

task automatic test_interleaved_write_sub(input bit [1:0] bank, input int wait_clk);
bit [26:0] addr;
bit [31:0] data, dout;
    addr = 0;
    addr[24:23] = bank;
    addr[18:17] = bank;
    addr[5:4] = bank;
    data[31:0] = {{8{bank}}, {8{~bank}}};
    sdram_write(addr, data[15:0]);
    sdram_write(addr+2, data[31:16]);

    repeat (wait_clk) @(posedge clk) ;

    ba <= addr_to_bank(addr);
    a[11:0] <= addr_to_row(addr);
    cmd(CMD_ACTIVE, 2 * 4);

    ba <= addr_to_bank(addr);
    a[11] <= 0;
    a[10] <= 1; // auto-precharge
    a[9:0] <= addr_to_col(addr);
    dqi <= data[15:0];
    cmd(CMD_WRITE, 1);
    dqi <= data[31:16];
    @(posedge clk) ;

    sdram_read(addr, dout);
    assert(dout === data[15:0]);
    sdram_read(addr+2, dout);
    assert(dout === data[31:16]);
endtask

task test_interleaved_write;
    dqml <= '0;
    dqmh <= '0;
    fork
        test_interleaved_write_sub(2'b00, 0);
        test_interleaved_write_sub(2'b01, 2);
        test_interleaved_write_sub(2'b10, 4);
        test_interleaved_write_sub(2'b11, 6);
    join
    dqml <= '1;
    dqmh <= '1;
    dqi <= 'Z;

    intertest_pause();
endtask

//////////////////////////////////////////////////////////////////////

initial forever begin :clkgen_ram
    #0.005 clk = ~clk; // 100 MHz
end

initial #0 begin
    power_up();

    test_read_auto_tras_min;
    test_read_tras_min;
    test_fast_activate;
    test_interleaved_read;
    test_interleaved_write;

    #0.2 $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s as4c32m16sb_tb -o as4c32m16sb_tb.vvp ../sdram.sv sdram_xsds.sv as4c32m16sb.sv as4c32m16sb_tb.sv && ./as4c32m16sb_tb.vvp"
// End:
