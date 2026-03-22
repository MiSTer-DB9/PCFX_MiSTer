// HuC6272 (KING) DRAM memory controller
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_dmc
   (
    input         CLK,
    input         CE,
    input         RESn,

    // Client interface
    input [17:1]  A,
    output [15:0] DI,
    input [15:0]  DO,
    input [1:0]   BE, // Byte Enable
    input         WR, // Write / not Read
    input         REQ, // Access request
    output        ACK, // Access acknowledge

    // DRAM interface
    input [15:0]  R_DI,
    output [15:0] R_DO,
    output [8:0]  R_A,
    output        R_OEn,
    output        R_WEn,
    output        R_RASn,
    output        R_LCASn,
    output        R_UCASn
    );

logic               rract, rrtrg, rrend;
logic [18:1]        ra;
logic [8:0]         rao;
logic [15:0]        rdi;
logic               rras, rcas, rio;
logic               rrav, rcav;

assign rrtrg = REQ & ~WR;
assign rrend = CE & rio;

always @(posedge CLK) begin
    if (~RESn) begin
        rract <= '0;
    end
    else begin
        if (~rract)
            rract <= rrtrg;
        else
            rract <= ~rrend;
    end
end

always @(posedge CLK) begin
    if (~rract & rrtrg)
        ra <= {1'b0, A};
end

always @(posedge CLK) begin
    if (~RESn) begin
        rao <= '0;
        rras <= 0;
        rcas <= 0;
        rio <= 0;
    end
    else if (CE & rract) begin
        if (~rras) begin
            rras <= '1;
            rao <= ra[18:10];
        end
        else if (~rcas) begin
            rcas <= '1;
            rao <= ra[9:1];
        end
        else if (~rio) begin
            rio <= '1;
        end
        else begin
            rras <= '0;
            rcas <= '0;
            rio <= '0;
            rao <= '0;
        end
    end
end

assign DI = R_DI;
assign ACK = rrend;

assign R_A = rao;
assign R_OEn = '0;
assign R_WEn = '1;
assign R_RASn = ~rras;
assign R_LCASn = ~rcas;
assign R_UCASn = ~rcas;

endmodule
