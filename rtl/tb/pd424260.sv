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
logic [15:0]    rbuf, rout, wbuf;
logic           inited = 0;
logic           rac = 0, rcd = 0, cac = 0, aa = 1;
logic [1:0]     wen = 0, ws = 0;

task read(input [8:0] row, input [8:0] col, output [15:0] d);
    d = mem[row][col];
endtask

task write(input [8:0] row, input [8:0] col, input [15:0] d);
    mem[row][col] = d;
endtask

initial @(negedge RASn)
    inited = 1;

always @(edge RASn) begin
    if (~RASn) begin // negedge
        row <= A;
        #70 rac <= 1;
    end
    else begin // posedge
        if (inited)
            assert(rac);
        rac <= 0;
    end
end

always @(edge RASn) begin
    if (~RASn) // negedge
        #20 rcd <= 1;
    else // posedge
        rcd <= 0;
end

always @(A) begin
    aa <= 0;
    #35 aa <= 1;
end

always @(edge LCASn or edge UCASn) begin
    if (~(LCASn | UCASn)) begin // negedge
        if (inited)
            assert(rcd);
        col <= A;
        #20 cac <= 1;
    end
    else if (LCASn & UCASn) begin // posedge
        if (inited)
            assert(cac);
        cac <= 0;
    end
end

always_latch begin
    if (~WEn & ~RASn) begin
        wbuf = OEn ? IO : 'X;
        wen = ~{UCASn, LCASn};
    end
    else if (RASn) begin
        ws = wen;
        wen = 0;
    end
end

always @(ws) begin
    if (ws[0])
        mem[row][col][0+:8] <= wbuf[0+:8];
    if (ws[1])
        mem[row][col][8+:8] <= wbuf[8+:8];
end

assign rbuf = mem[row][col];

assign rout = (rac & cac & aa) ? rbuf : 'X;

assign IO[0+:8] = (~OEn & ~LCASn) ? rout[0+:8] : 'Z;
assign IO[8+:8] = (~OEn & ~UCASn) ? rout[8+:8] : 'Z;

endmodule
