// HuC6261 (NEW Iron Guanyin)
//
// Copyright (c) 2025-2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

// References:
// - https://github.com/MiSTer-devel/TurboGrafx16_MiSTer/blob/master/rtl/huc6260.vhd
// - PC-FXGA Authoring Software / GMAKER Starter Kit (Ver. 1.1) / Device Description: Hu6261


module huc6261
    (
     input            CLK,
     input            CE,
     input            RESn,

     input            CSn,
     input            WRn,
     input            RDn,
     input            A2,
     input [15:0]     DI,
     output [15:0]    DO,

     // VDC interface
     output           DCK70, // pixel clock enable
     output           DCK70_NEGEDGE,
     output reg       HSYNC_POSEDGE,
     output reg       HSYNC_NEGEDGE,
     output reg       VSYNC_POSEDGE,
     output reg       VSYNC_NEGEDGE,

     input [8:0]      VDC0_VD,
     input [8:0]      VDC1_VD,

     // MMC (HuC6272 KING) video interface
     output           DCKKR, // pixel clock enable
     output           DCKKR_NEGEDGE,
     input [23:0]     MMC_VD,

     // NTSC/YUV video output
     output reg [7:0] Y,
     output reg [7:0] U,
     output reg [7:0] V,
     output reg       VSn,
     output reg       HSn,
     output reg       VBL,
     output reg       HBL
     );

localparam [11:0] LEFT_BL_CLOCKS = 12'd457;
localparam [11:0] DISP_CLOCKS = 12'd2160;
localparam [11:0] LINE_CLOCKS = 12'd2730;
localparam [11:0] HS_CLOCKS = 12'd192;
localparam [11:0] HS_OFF = 12'd47;

localparam [8:0] TOTAL_LINES = 9'd263;
localparam [8:0] VS_LINES = 9'd3;
localparam [8:0] TOP_BL_LINES_E = 9'd19;
localparam [8:0] DISP_LINES_E = 9'd242;

localparam [8:0] TOP_BL_LINES = TOP_BL_LINES_E;
localparam [8:0] DISP_LINES = DISP_LINES_E;

localparam NL = 3;

typedef struct packed {
    logic bg71;
    logic [3:0] bmg;
    logic sp;
    logic bg;
    logic sp256;
    logic bg256;
    logic [1:0] rsv4;
    logic dc7;
    logic ex;
    logic [1:0] dcc;
} cr_t;

typedef struct packed {
    logic [2:0]     pri;
    logic           key;
    logic [23:0]    vd;
    logic           pal;
} layer_t;

logic [4:0]     ar;
logic [11:0]    h_cnt;
logic [8:0]     v_cnt;

cr_t            cr, cr_next;
logic [8:0]     cpa;
logic [15:0]    cpdin, cpdout;
logic           cpd_wr, cpd_wr_d;
logic [7:0]     vdc_sp_cpao, vdc_bg_cpao;
logic [2:0]     pri_vdc_bg, pri_vdc_sp, pri_vpu,
                pri_mmc_bg0, pri_mmc_bg1, pri_mmc_bg2, pri_mmc_bg3;

layer_t [NL:0]  layers;

//////////////////////////////////////////////////////////////////////
// Register interface

logic [15:0]    dout;

wire cpd_wr_end = ~cpd_wr & cpd_wr_d;

always @(posedge CLK) if (CE) begin
    cpd_wr <= '0;
    cpd_wr_d <= cpd_wr;

    if (~RESn) begin
        cr_next <= '0;
        ar <= '0;
        cpa <= '0;
        vdc_sp_cpao <= '0;
        vdc_bg_cpao <= '0;
    end
    else begin
        if (cpd_wr_end)
            cpa <= cpa + 1'd1;

        if (~CSn & ~WRn) begin
            case (A2)
                1'b0: begin
                    ar <= DI[4:0];
                end
                1'b1: begin
                    case (ar)
                        5'd00:
                            cr_next <= DI[14:0];
                        5'd01:
                            cpa <= DI[8:0];
                        5'd02: begin
                            cpdin <= DI[15:0];
                            cpd_wr <= '1;
                        end
                        5'd04: begin
                            vdc_sp_cpao <= DI[15:8];
                            vdc_bg_cpao <= DI[7:0];
                        end
                        5'h08: begin
                            pri_vdc_bg <= DI[0+:3];
                            pri_vdc_sp <= DI[4+:3];
                            pri_vpu <= DI[8+:3];
                        end
                        5'h09: begin
                            pri_mmc_bg0 <= DI[0+:3];
                            pri_mmc_bg1 <= DI[4+:3];
                            pri_mmc_bg2 <= DI[8+:3];
                            pri_mmc_bg3 <= DI[12+:3];
                        end
                        default: ;
                    endcase
                end
            endcase
        end
    end
end

always @* begin
    dout = '0;
    case (A2)
        1'b0: begin
            dout[4:0] = ar;
            dout[13:5] = v_cnt;
        end
        1'b1: begin
            case (ar)
                5'd03:
                    dout[15:0] = cpdout;
                5'h08: begin
                    dout[0+:3] = pri_vdc_bg;
                    dout[4+:3] = pri_vdc_sp;
                    dout[8+:3] = pri_vpu;
                end
                5'h09: begin
                    dout[0+:3] = pri_mmc_bg0;
                    dout[4+:3] = pri_mmc_bg1;
                    dout[8+:3] = pri_mmc_bg2;
                    dout[12+:3] = pri_mmc_bg3;
                end
                default: ;
            endcase
        end
    endcase
end

assign DO = (~CSn & ~RDn) ? dout : '0;

//////////////////////////////////////////////////////////////////////
// Video counter

logic           multires, multires_p;

wire h_wrap = h_cnt == (LINE_CLOCKS - 1'd1);
wire v_wrap = v_cnt == (TOTAL_LINES - 1'd1);

always @(posedge CLK) begin
    if (~RESn) begin
        h_cnt <= '0;
        v_cnt <= '0;
    end
    else begin
        if (~h_wrap)
            h_cnt <= h_cnt + 1'd1;
        else begin
            h_cnt <= '0;
            if (~v_wrap)
                v_cnt <= v_cnt + 1'd1;
            else
                v_cnt <= '0;
        end
    end
end

// Some registers update only every line or frame.
always @(posedge CLK) begin
    if (~RESn) begin
        cr <= '0;
        multires_p <= '0;
        multires <= '0;
    end
    else begin
        if (h_wrap) begin
            cr <= cr_next;
        end

        if ((v_cnt >= TOP_BL_LINES) & (v_cnt < (TOP_BL_LINES + DISP_LINES)) &
            (cr.dc7 != cr_next.dc7))
            multires_p <= '1;

        if (v_cnt == TOP_BL_LINES + DISP_LINES) begin
            multires <= multires_p;
            multires_p <= '0;
        end
    end
end

//////////////////////////////////////////////////////////////////////
// VDC (HuC6270) Pixel clock generator
//
// Variable rate for 256 or 320 horizontal pixels

logic [2:0]     cken70_cnt;
logic           cken70, cken70_ne;

always @(posedge CLK) begin
    cken70 <= '0;
    cken70_ne <= '0;

    if (~RESn) begin
        cken70_cnt <= '0;
    end
    else begin
        cken70_cnt <= cken70_cnt + 1'd1;

        if ((((multires & (cken70_cnt == 3'd3))
              | (cr.dc7 == 1'b0 & ((cken70_cnt == 3'd7))))
             & (h_cnt < (LINE_CLOCKS - 12'(2+1))))
            | (cr.dc7 == 1'b1 & (cken70_cnt == 3'd5))
            | h_wrap) begin
            cken70_cnt <= '0;
            cken70 <= '1;
        end
        if (((cr.dc7 == 1'b0) & (cken70_cnt == 3'd3))
            | ((cr.dc7 == 1'b1) & (cken70_cnt == 3'd2)))
            cken70_ne <= '1;
    end
end

assign DCK70 = cken70;
assign DCK70_NEGEDGE = cken70_ne;

//////////////////////////////////////////////////////////////////////
// VPU (HuC6271 RAINBOW) / MMC (HuC6272 KING) Pixel clock generator
//
// Fixed rate for 256 horizontal pixels

logic [2:0]     ckenkr_cnt;
logic           ckenkr, ckenkr_ne;

always @(posedge CLK) begin
    ckenkr <= '0;
    ckenkr_ne <= '0;

    if (~RESn) begin
        ckenkr_cnt <= '0;
    end
    else begin
        ckenkr_cnt <= ckenkr_cnt + 1'd1;

        if (((ckenkr_cnt == 3'd7)
             & (h_cnt < (LINE_CLOCKS - 12'(2+1))))
            | h_wrap) begin
            ckenkr_cnt <= '0;
            ckenkr <= '1;
        end
        if (ckenkr_cnt == 3'd3)
            ckenkr_ne <= '1;
    end
end

assign DCKKR = ckenkr;
assign DCKKR_NEGEDGE = ckenkr_ne;

//////////////////////////////////////////////////////////////////////
// VDC MUX

logic             vdc_en, vdc_key;
logic [8:0]       vdc_vd;
logic             vdc_spbg;
logic [8:0]       vdc_cpa_bg, vdc_cpa_sp;

wire vdc0_key = VDC0_VD[7:0] != '0;
wire vdc1_key = VDC1_VD[7:0] != '0;

// "Upper" 6270 has priority over "lower".
assign vdc_vd = ~vdc1_key ? VDC0_VD : VDC1_VD;
assign vdc_spbg = vdc_vd[8];
assign vdc_en = vdc_spbg ? cr.sp : cr.bg;
assign vdc_key = vdc_en & (vdc0_key | vdc1_key);

assign vdc_cpa_bg = {vdc_bg_cpao, 1'b0} + {1'b0, vdc_vd[7:0]};
assign vdc_cpa_sp = {vdc_sp_cpao, 1'b0} + {1'b0, vdc_vd[7:0]};

assign layers[0].pri = pri_vdc_bg;
assign layers[0].key = ~vdc_spbg & vdc_key;
assign layers[0].vd  = 24'(vdc_cpa_bg);
assign layers[0].pal = '1;
assign layers[1].pri = pri_vdc_sp;
assign layers[1].key = vdc_spbg & vdc_key;
assign layers[1].vd  = 24'(vdc_cpa_sp);
assign layers[1].pal = '1;

//////////////////////////////////////////////////////////////////////
// MMC (KING) video input

logic           mmc_en, mmc_key;

assign mmc_en = cr.bmg[0];
assign mmc_key = mmc_en & |MMC_VD[16+:8];

// MMC BG0
assign layers[2].pri = pri_mmc_bg0;
assign layers[2].key = mmc_key;
assign layers[2].vd  = MMC_VD;
assign layers[2].pal = '0;

//////////////////////////////////////////////////////////////////////
// Layer priority encoder

logic [$clog2(NL+1)-1:0]    prio_out;
logic [2:0]                 prio_pri [NL];
logic [NL-1:0]              prio_key;

// Background for when all layers are transparent
assign layers[NL].pri = '0;
assign layers[NL].key = '1;
assign layers[NL].vd  = '0;
assign layers[NL].pal = '1;

genvar i;
generate
    for (i = 0; i < NL; i++) begin :prio_layers
        assign prio_pri[i] = layers[i].pri;
        assign prio_key[i] = layers[i].key;
    end
endgenerate

huc6261_prio #(.N(NL)) prio
   (
    .CLK(CLK),
    .PRI(prio_pri),
    .KEY(prio_key),
    .OUT(prio_out)
    );

//////////////////////////////////////////////////////////////////////
// Video layer MUX

layer_t vmux;

assign vmux = layers[prio_out];

//////////////////////////////////////////////////////////////////////
// Palette RAM address generator

logic [8:0]       cpa_out;

always @* begin
    cpa_out = '0;
    if (vmux.pal)
        cpa_out = vmux.vd[8:0];
end

//////////////////////////////////////////////////////////////////////
// Color palette RAM

logic [15:0]    cp_out;

dpram #(.addr_width(9), .data_width(16)) cpram
   (
    .clock(CLK),
    .address_a(cpa),
    .data_a(cpdin),
    .enable_a(1'b1),
    .wren_a(cpd_wr),
    .q_a(cpdout),
    .cs_a(1'b1),

    .address_b(cpa_out),
    .data_b('0),
    .enable_b(1'b1),
    .wren_b('0),
    .q_b(cp_out),
    .cs_b(1'b1)
    );

//////////////////////////////////////////////////////////////////////
// Video mixer, YUV

logic [23:0]    mix_vd;
logic [7:0]     mix_out_y, mix_out_u, mix_out_v;

always @(posedge CLK) begin
    mix_vd <= vmux.vd;
end

always @* begin
    if (vmux.pal) begin
        mix_out_y = cp_out[8+:8];
        mix_out_u = {cp_out[7:4], cp_out[6:4], cp_out[6]};
        mix_out_v = {cp_out[3:0], cp_out[2:0], cp_out[2]};
    end
    else
        {mix_out_y, mix_out_u, mix_out_v} = mix_vd;
end

//////////////////////////////////////////////////////////////////////
// Sync generators

logic [11:0]    hsync_start_pos, hsync_end_pos;
logic           hbl_ff, vbl_ff;

always @* begin
    hsync_start_pos = (cr.dc7 ? (LINE_CLOCKS - 12'd6) : 12'd8) - 1'd1;
    hsync_end_pos = (cr.dc7 ? (12'd468 - 12'd6) : (12'd8 + 12'd464)) - 1'd1;
end

// These syncs are for the VDCs.
always @(posedge CLK) begin
    HSYNC_NEGEDGE <= (h_cnt == hsync_start_pos);
    HSYNC_POSEDGE <= (h_cnt == hsync_end_pos);
    VSYNC_NEGEDGE <= ((v_cnt == VS_LINES - 1'd1) & h_wrap);
    VSYNC_POSEDGE <= (v_wrap & h_wrap);
end

// These syncs are for the actual video output.
always @(posedge CLK) begin
    if (h_cnt == HS_OFF)
        HSn <= '0;
    else if (h_cnt == HS_OFF + HS_CLOCKS)
        HSn <= '1;

    if (v_cnt == 9'd0)
        VSn <= '0;
    else if (v_cnt == VS_LINES)
        VSn <= '1;
end

// Blanking periods
always @(posedge CLK) begin
    if (h_cnt == LEFT_BL_CLOCKS)
        hbl_ff <= '0;
    else if (h_cnt == LEFT_BL_CLOCKS + DISP_CLOCKS)
        hbl_ff <= '1;

    if (v_cnt == TOP_BL_LINES)
        vbl_ff <= '0;
    else if (v_cnt == TOP_BL_LINES + DISP_LINES)
        vbl_ff <= '1;
end

//////////////////////////////////////////////////////////////////////
// Final output

always @(posedge CLK) if (DCK70) begin
    VBL <= vbl_ff;
    HBL <= hbl_ff;

    Y <= mix_out_y;
    U <= mix_out_u;
    V <= mix_out_v;
end

endmodule

`include "huc6261_prio.sv"
