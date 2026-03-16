// HuC6272 (KING) video fetch engine, one bank
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_fetch
   (
    input         CLK,
    input         CE,
    input         RESn,

    // Register file
    input         rf_bgm_t rf_bgm,

    // Render control interface
    input         DCK, // pixel clock enable
    input         FETCH,
    input [9:0]   FETCH_BG_ROW,
    input [9:0]   FETCH_BG_COL,

    // Microprogram data store interface
    input         mpd_t MPRBUF,

    // Memory client interface
    output [18:1] M_A,
    input [15:0]  M_DI,
    output [15:0] M_DO,
    output [1:0]  M_BE,
    output        M_WR,
    output        M_REQ,
    input         M_ACK,

    // Fetched CG data
    output        MDS,
    output [1:0]  MDL,
    output [15:0] MD
    );

//////////////////////////////////////////////////////////////////////
// Microprogram engine

mpd_t               mpe_d;
logic [18:1]        mpe_ra;
logic               mpe_ren;
logic [1:0]         mpe_layer;

assign mpe_d = FETCH ? MPRBUF : 9'h100;

function [18:1] mpe_addr(mpd_t mpd);
logic [7:0] base;
rf_bgp_t bgp;
    bgp = get_bgp(mpd.layer);
    mpe_addr = '0;
    if (~mpd.nop) begin
        mpe_addr[16:10] = mpd.bat ? bgp.bat[6:0] : bgp.cg[6:0]; // [7] is A/-B
        if (mpd.bat)
            ; // TODO
        else // CG
            mpe_addr += {FETCH_BG_ROW[7:0], FETCH_BG_COL[7:3], mpd.cgoff};
    end
endfunction

always @(posedge CLK) begin
    mpe_ren <= ~mpe_d.nop;
    mpe_layer <= mpe_d.layer;
    mpe_ra <= mpe_addr(mpe_d);
end

//////////////////////////////////////////////////////////////////////
// Bank A/B memory client interface

logic               mtrg, mreq, mack;
logic [1:0]         mdl;
logic [18:1]        ma, ma_d;
logic [15:0]        md;

assign ma = mpe_ra;
assign mtrg = mpe_ren & FETCH & DCK;
assign mack = M_REQ & M_ACK;

always @(posedge CLK) begin
    if (~RESn) begin
        ma_d <= '0;
        mdl <= '0;
        md <= '0;
        mreq <= '0;
    end
    else begin
        mreq <= M_REQ & ~M_ACK;

        if (mtrg) begin
            ma_d <= ma;
            mdl <= mpe_layer;
        end
        if (mack)
            md <= M_DI;
    end
end

assign M_A = ma;
assign M_BE = '1;
assign M_WR = '0;
assign M_REQ = mreq | mtrg;

assign MDS = mack;
assign MDL = mdl;
assign MD = md;

endmodule
