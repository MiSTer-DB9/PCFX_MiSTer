// HuC6272 (KING) video
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_bgm
   #(parameter LAYER=0)
   (
    input         CLK,
    input         CE,
    input         RESn,

    // Register file
    input         rf_bgm_t rf_bgm,

    input         DCK,
    input         RENDER,
    input [9:0]   RENDER_BG_COL,

    input         MBA1,
    input [15:0]  MBD,
    input         MBACK,
    
    output [23:0] PD,
    output        PDE
    );

wire format_clr_16m = ((rf_bgm.bgp[LAYER].format == BGF_INT_DOT_16M) |
                       (rf_bgm.bgp[LAYER].format == BGF_EXT_BLK_16M) |
                       (rf_bgm.bgp[LAYER].format == BGF_EXT_DOT_16M));

logic               cgfce;
logic [15:0]        cgrd_in;
logic [31:0]        cgrd;
logic               cgra;
logic [23:0]        cgpd, cgpdo; // {Y,U,V}
logic               cgpdeo;

wire cgrce = DCK;

always @(posedge CLK)
    cgfce <= MBACK;

always @(posedge CLK) begin
    if (~RESn) begin
        cgra <= '0;
        cgrd <= '0;
        cgrd_in <= '0;
    end
    else if (cgfce) begin
        cgra <= MBA1;
        cgrd_in <= MBD;
        if (format_clr_16m) begin
            if (MBA1)
                cgrd <= {cgrd_in, MBD};
        end
        else
            cgrd <= {16'b0, cgrd_in};
    end
end

always @* begin
    if (format_clr_16m) begin
        // 16M CG is ordered in KRAM as {Y0,Y1,U,V}.
        cgpd[16+:8] = ~RENDER_BG_COL[0] ? cgrd[24+:8] : cgrd[16+:8];
        cgpd[0+:16] = cgrd[0+:16];
    end
    if (~RENDER)
        cgpd = '0;
end

always @(posedge CLK) begin
    if (~RESn) begin
        cgpdo <= '0;
        cgpdeo <= '0;
    end
    else if (cgrce) begin
        cgpdo <= cgpd;
        cgpdeo <= RENDER;
    end
end

assign PD = cgpdo;
assign PDE = cgpdeo;

endmodule
