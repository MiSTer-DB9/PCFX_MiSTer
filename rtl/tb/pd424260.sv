// NEC uPD424260-70 - 4Mbit (256Kx16) fast page DRAM
//
// Copyright (c) 2026 David Hunter

// TODO:
// - Enforce timing
// - Write cycle
// - Refresh

`timescale 1ns / 1ns

module pd424260
   (
    inout [15:0]  IO,
    input [8:0]   A,
    input         OEn,
    input         WEn,
    input         RASn,
    input         LCASn,
    input         UCASn
    );

logic [8:0]     row;
logic [8:0]     col;
logic [15:0] 	mem[1<<9][1<<9];
logic [15:0]    rbuf, rout;
logic           rac = 0, rcd = 0, cac = 0, aa = 1;

task read(input [8:0] row, input [8:0] col, output [15:0] d);
    d = mem[row][col];
endtask

task write(input [8:0] row, input [8:0] col, input [15:0] d);
    mem[row][col] = d;
endtask

always @(negedge RASn) begin
    row <= A;
    #70 rac <= 1;
end

always @(negedge RASn)
    #20 rcd <= 1;

always @(posedge RASn) begin
    if ($time)
        assert(rac);
    rac <= 0;
    rcd <= 0;
end

always @(A) begin
    aa <= 0;
    #35 aa <= 1;
end

always @(negedge LCASn or negedge UCASn) begin
    if ($time)
        assert(rcd);
    #20 cac <= 1;
    col <= A;
end

always @(posedge LCASn or posedge UCASn) begin
    if ($time)
        assert(cac);
    cac <= 0;
end

assign rbuf = mem[row][col];

assign rout = (rac & cac & aa) ? rbuf : 'X;

assign IO[0+:8] = (~OEn & ~LCASn) ? rout[0+:8] : 'Z;
assign IO[8+:8] = (~OEn & ~UCASn) ? rout[8+:8] : 'Z;

endmodule
