// Memory fabric to connect one client to both banks
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_fabric_tee
   (
    input         M_BA,
    output [15:0] M_DI,
    input         M_REQ,
    output        M_ACK,

    input [15:0]  MA_DI,
    output        MA_REQ,
    input         MA_ACK,

    input [15:0]  MB_DI,
    output        MB_REQ,
    input         MB_ACK
    );

assign MA_REQ = ~M_BA & M_REQ;
assign MB_REQ =  M_BA & M_REQ;

assign M_DI = M_BA ? MB_DI : MA_DI;
assign M_ACK = M_BA ? MB_ACK : MA_ACK;

endmodule
