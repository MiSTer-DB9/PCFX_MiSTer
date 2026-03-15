// HuC6272 (KING) video
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_video
   (
    input         CLK,
    input         CE,
    input         RESn,

    // Register file
    input         rf_bgm_t rf_bgm,

    // Bank A memory client interface
    output [18:1] MA_A,
    input [15:0]  MA_DI,
    output [15:0] MA_DO,
    output [1:0]  MA_BE,
    output        MA_WR,
    output        MA_REQ,
    input         MA_ACK,

    // Bank B memory client interface
    output [18:1] MB_A,
    input [15:0]  MB_DI,
    output [15:0] MB_DO,
    output [1:0]  MB_BE,
    output        MB_WR,
    output        MB_REQ,
    input         MB_ACK,

    // Video interface
    input         DCK, // pixel clock enable
    input         DCK_NEGEDGE,
    input         HSYNC_POSEDGE,
    input         HSYNC_NEGEDGE,
    input         VSYNC_POSEDGE,
    input         VSYNC_NEGEDGE,
    output [23:0] VD, // [7:0] = palette data / [23:0] = {Y,U,V}
    output        VDE
    );

logic [9:0]         row, col;

//////////////////////////////////////////////////////////////////////
// Video counter

logic               vsync_l;

always @(posedge CLK) begin
    if (~RESn) begin
        row <= '0;
        col <= '0;
        vsync_l <= '0;
    end
    else if (DCK) begin
        col <= col + 1'd1;
        if (HSYNC_NEGEDGE) begin
            col <= '0;
            row <= row + 1'd1;
            if (vsync_l) begin
                row <= '0;
                vsync_l <= '0;
            end
        end
        if (VSYNC_NEGEDGE)
            vsync_l <= '1;
    end
end

//////////////////////////////////////////////////////////////////////
// Active fetch / render windows

localparam [9:0] FETCH_ROW_START = 10'd7;
localparam [9:0] FETCH_ROW_END = FETCH_ROW_START + 10'd240 - 10'd1;
localparam [9:0] FETCH_COL_START = 10'd17;
localparam [9:0] FETCH_COL_END = FETCH_COL_START + 10'd256 - 10'd1;

wire fetch_row = (row >= FETCH_ROW_START) & (row <= FETCH_ROW_END);
wire fetch_col = (col >= FETCH_COL_START) & (col <= FETCH_COL_END);
wire fetch = fetch_row & fetch_col;

wire [9:0] fetch_bg_row = row - FETCH_ROW_START;
wire [9:0] fetch_bg_col = col - FETCH_COL_START;

localparam [9:0] RENDER_ROW_START = FETCH_ROW_START;
localparam [9:0] RENDER_ROW_END = FETCH_ROW_END;
localparam [9:0] RENDER_COL_START = 10'd20;
localparam [9:0] RENDER_COL_END = RENDER_COL_START + 10'd256 - 10'd1;

wire render_row = (row >= RENDER_ROW_START) & (row <= RENDER_ROW_END);
wire render_col = (col >= RENDER_COL_START) & (col <= RENDER_COL_END);
wire render = render_row & render_col;

wire [9:0] render_bg_row = row - RENDER_ROW_START;
wire [9:0] render_bg_col = col - RENDER_COL_START;

//////////////////////////////////////////////////////////////////////
// Bank A/B memory client interfaces

logic               mbtrg, mbreq, mback;
logic [18:1]        mba, mba_d;
logic [15:0]        mbd;

assign mba = {fetch_bg_row[7:0], fetch_bg_col[7:0]};
assign mbtrg = fetch & DCK;
assign mback = MB_REQ & MB_ACK;

always @(posedge CLK) begin
    if (~RESn) begin
        mba_d <= '0;
        mbd <= '0;
        mbreq <= '0;
    end
    else begin
        mbreq <= MB_REQ & ~MB_ACK;

        if (mbtrg)
            mba_d <= mba;
        if (mback)
            mbd <= MB_DI;
    end
end

assign MB_A = mba;
assign MB_BE = '1;
assign MB_WR = '0;
assign MB_REQ = mbreq | mbtrg;

//////////////////////////////////////////////////////////////////////
// BG pipelines

logic [23:0]        bg0_pd;
logic               bg0_pde;

huc6272_bgm #(0) bg0
   (
    .CLK(CLK),
    .CE(CE),
    .RESn(RESn),

    .rf_bgm(rf_bgm),

    .DCK(DCK),
    .RENDER(render),
    .RENDER_BG_COL(render_bg_col),

    .MBA1(mba_d[1]),
    .MBD(mbd),
    .MBACK(mback),

    .PD(bg0_pd),
    .PDE(bg0_pde)
    );

//////////////////////////////////////////////////////////////////////
// Final video output

assign VD = bg0_pd;
assign VDE = bg0_pde;

endmodule
