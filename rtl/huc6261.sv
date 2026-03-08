// HuC6261 (NEW Iron Guanyin)
//
// Copyright (c) 2025 David Hunter
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

localparam [11:0] LEFT_BL_CLOCKS = 12'd456;
localparam [11:0] DISP_CLOCKS = 12'd2160;
localparam [11:0] LINE_CLOCKS = 12'd2730;
localparam [11:0] HS_CLOCKS = 12'd192;
localparam [11:0] HS_OFF = 12'd46;

localparam [8:0] TOTAL_LINES = 9'd263;
localparam [8:0] VS_LINES = 9'd3;
localparam [8:0] TOP_BL_LINES_E = 9'd19;
localparam [8:0] DISP_LINES_E = 9'd242;

localparam [8:0] TOP_BL_LINES = TOP_BL_LINES_E;
localparam [8:0] DISP_LINES = DISP_LINES_E;

typedef struct packed {
    logic bg71;
    logic [3:0] bmg;
    logic sp;
    logic bp;
    logic sp256;
    logic bp256;
    logic [1:0] rsv4;
    logic dc7;
    logic ex;
    logic [1:0] dcc;
} cr_t;

logic [4:0]     ar;
logic [11:0]    h_cnt;
logic [8:0]     v_cnt;

cr_t            cr, cr_next;
logic [8:0]     cpa;
logic [15:0]    cpdin, cpdout;
logic           cpd_wr, cpd_wr_d;
logic [7:0]     vdc_sp_cpao, vdc_bg_cpao;

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
// Video mixer

logic             vdc_key;
logic [8:0]       vdc_vd;
logic [8:1]       vdc_cpao;
logic [8:0]       vdc_cpa;
logic [8:0]       mix_cpa_out;

wire vdc0_key = VDC0_VD[7:0] == '0;
wire vdc1_key = VDC1_VD[7:0] == '0;

// "Upper" 6270 has priority over "lower".
assign vdc_key = vdc0_key & vdc1_key;
assign vdc_vd = vdc1_key ? VDC0_VD : VDC1_VD;

// Palette RAM address generator
assign vdc_cpao = vdc_vd[8] ? vdc_sp_cpao : vdc_bg_cpao;
assign vdc_cpa = {vdc_cpao, 1'b0} + {1'b0, vdc_vd[7:0]};

// Chromakey (transparency) priority encoder
always @* begin
    mix_cpa_out = '0;
    if (~vdc_key)
        mix_cpa_out = vdc_cpa;
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

    .address_b(mix_cpa_out),
    .data_b('0),
    .enable_b(1'b1),
    .wren_b('0),
    .q_b(cp_out),
    .cs_b(1'b1)
    );

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

    Y <= cp_out[15:8];
    U <= {cp_out[7:4], cp_out[6:4], cp_out[6]};
    V <= {cp_out[3:0], cp_out[2:0], cp_out[2]};
end

endmodule
