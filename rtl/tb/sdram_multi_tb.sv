// SDRAM controller multiple access testbench
//
// Intent is to simulate what happens if we do combined reads from two
// King fast-page DRAM controllers and the CPU DRAM controller.
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module sdram_multi_tb;

logic		reset;
logic       clk_sys, clk_ram;

initial begin
    $timeformat(-6, 0, " us", 1);

`ifndef VERILATOR
    $dumpfile("sdram_multi_tb.vcd");
    $dumpvars();
`else
    $dumpfile("sdram_multi_tb.verilator.fst");
    $dumpvars();
`endif
end

//////////////////////////////////////////////////////////////////////
// Memory

wire        SDRAM_CLK;
wire        SDRAM_CKE;
wire [12:0] SDRAM_A;
wire [1:0]  SDRAM_BA;
wire [15:0] SDRAM_DQ;
wire        SDRAM_DQML;
wire        SDRAM_DQMH;
wire        SDRAM_nCS;
wire        SDRAM_nCAS;
wire        SDRAM_nRAS;
wire        SDRAM_nWE;

// Clock rate matches N64_MiSTer. TODO: Match PCFX_MiSTer.
sdram_xsds #(.CLK_MHZ(62.5)) sdrb (.*);

task sdram_read(input [26:0] addr, output [15:0] d);
    sdrb.u1a.read(sdram.addr_to_bank(addr),
                  sdram.addr_to_row(addr),
                  sdram.addr_to_col(addr),
                  d);
endtask

task sdram_write(input [26:0] addr, input [15:0] d);
    sdrb.u1a.write(sdram.addr_to_bank(addr),
                   sdram.addr_to_row(addr),
                   sdram.addr_to_col(addr),
                   d);
endtask

//////////////////////////////////////////////////////////////////////
// SDRAM controller

logic           sdram_init;
logic [26:0]    ch1_addr, ch2_addr, ch3_addr;
logic [31:0]    ch1_dout, ch2_dout, ch3_dout;
logic [31:0]    ch1_din, ch2_din, ch3_din;
logic           ch1_req, ch2_req, ch3_req;
logic           ch1_rnw, ch2_rnw, ch3_rnw;
logic [3:0]     ch1_be;
logic           ch1_ready, ch2_ready, ch3_ready;

sdram sdram
   (
    .*,

    .init(sdram_init),
    .clk(clk_ram),

    .ch1_addr(ch1_addr),
    .ch1_dout(ch1_dout),
    .ch1_din(ch1_din),
    .ch1_req(ch1_req),
    .ch1_rnw(ch1_rnw),
    .ch1_be(ch1_be),
    .ch1_ready(ch1_ready),
    .ch1_reqprocessed(),

    .ch2_addr(ch2_addr),
    .ch2_dout(ch2_dout),
    .ch2_din(ch2_din),
    .ch2_req(ch2_req),
    .ch2_rnw(ch2_rnw),
    .ch2_ready(ch2_ready),

    .ch3_addr(ch3_addr),
    .ch3_dout(ch3_dout),
    .ch3_din(ch3_din),
    .ch3_req(ch3_req),
    .ch3_rnw(ch3_rnw),
    .ch3_ready(ch3_ready)    
    );

assign SDRAM_CLK = clk_ram;

//////////////////////////////////////////////////////////////////////
// Traffic generator

event           krama_read, kramb_read, cpu_read, cpu_write;

initial begin
    ch1_addr = 27'h00000;
    ch2_addr = 27'h10000;
    ch3_addr = 27'h20000;
    ch1_req = 0;
    ch2_req = 0;
    ch3_req = 0;
    ch1_be = '1;
end

always @(krama_read) begin :krama_read_blk
reg [15:0] d;
    sdram_read(ch2_addr, d);
    ch2_addr <= ch2_addr + 2'd2;
    ch2_rnw <= 1;
    ch2_req <= 1;
    @(posedge clk_ram) ch2_req <= 0;
    @(negedge ~ch2_ready) ;
    assert(ch2_dout[15:0] == d);
end

always @(kramb_read) begin :kramb_read_blk
reg [15:0] d;
    ch3_addr <= ch3_addr + 2'd2;
    ch3_rnw <= 1;
    ch3_req <= 1;
    @(posedge clk_ram) ch3_req <= 0;
    @(negedge ~ch3_ready) ;
    sdram_read(ch3_addr, d);
    assert(ch3_dout[15:0] == d);
end

always @(cpu_read) begin :cpu_read_blk
reg [31:0] d;
    ch1_addr <= ch1_addr + 3'd4;
    ch1_rnw <= 1;
    ch1_req <= 1;
    @(posedge clk_ram) ch1_req <= 0;
    @(negedge ch1_ready) ;
    sdram_read(ch1_addr, d[15:0]);
    sdram_read(ch1_addr+2, d[31:16]);
    assert(ch1_dout == d);
end

always @(cpu_write) begin :cpu_write_blk
reg [31:0] d;
    ch1_din <= ~ch1_dout;
    ch1_rnw <= 0;
    ch1_req <= 1;
    @(posedge clk_ram) ch1_req <= 0;
    @(negedge ~ch1_ready) ;
    repeat (5) @(posedge clk_ram) ; // wait for write to commit
    sdram_read(ch1_addr, d[15:0]);
    sdram_read(ch1_addr+2, d[31:16]);
    assert(d == ch1_din);
end

//////////////////////////////////////////////////////////////////////

initial begin
    sdram_init = 1;
    reset = 1;
    clk_sys = 1;
    clk_ram = 1;
end

initial forever begin :clkgen_sys
    #0.01 clk_sys = ~clk_sys; // 50 MHz
end

initial forever begin :clkgen_ram
    #0.005 clk_ram = ~clk_ram; // 100 MHz
end

always @(posedge clk_ram)
    if (sdram_init)
        sdram_init <= 0;

task load_sdram;
    for (bit [26:0] a = 0; a < 27'h30000; a ++)
        sdram_write(a, a[15:0] | {a[19:16], 12'b0});
endtask

initial #0 begin
    load_sdram();

    #150 ; // wait for sdram init.

    @(posedge clk_sys) reset = 0;
    repeat (10) @(posedge clk_sys) ;

    fork
        begin
            repeat (40) begin
                -> krama_read;
                -> kramb_read;
                repeat (10) @(posedge clk_sys) ;
            end
        end
        begin
            repeat (30) @(posedge clk_sys) ;
            repeat (10) begin
                -> cpu_read;
                repeat (16) @(posedge clk_sys) ;
                -> cpu_write;
                repeat (16) @(posedge clk_sys) ;
            end
        end
    join

    $finish;
end

endmodule

// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s sdram_multi_tb -o sdram_multi_tb.vvp ../sdram.sv sdram_xsds.sv as4c32m16sb.sv sdram_multi_tb.sv && ./sdram_multi_tb.vvp"
// End:
