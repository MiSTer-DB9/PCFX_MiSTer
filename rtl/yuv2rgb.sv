// Colorspace converter: YUV to RGB
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

// R = (Y + 1.40200 * (V - 128)
// G = (Y - 0.34414 * (U - 128) - 0.71414 * (V - 128)
// B = (Y + 1.77200 * (U - 128)

module yuv2rgb
   (
    input            CLK,

     // YUV video input
    input            I_PCE,
    input [7:0]      I_Y,
    input [7:0]      I_U,
    input [7:0]      I_V,
    input            I_VSn,
    input            I_HSn,
    input            I_VBL,
    input            I_HBL,

     // RGB video output
    output reg       O_PCE,
    output reg [7:0] O_R,
    output reg [7:0] O_G,
    output reg [7:0] O_B,
    output reg       O_VSn,
    output reg       O_HSn,
    output reg       O_VBL,
    output reg       O_HBL
    );

logic [2:0]         st = 0;
logic signed [7:0]  u, v, mam1;
logic signed [11:0] mam2;
logic signed [19:0] y, mao, maa;
logic [7:0]         co, r, b;
logic               maen;
logic               vsn, hsn, vbl, hbl;

localparam signed [11:0] V1 = 12'sd1436; /* 1.40200 * 1024 */
localparam signed [11:0] U1 = 12'sd1815; /* 1.77200 * 1024 */
localparam signed [11:0] V2 = -12'sd731; /* 0.71414 * 1024 */
localparam signed [11:0] U2 = -12'sd352; /* 0.34414 * 1024 */

function [7:0] clamp(input signed [9:0] in);
    if (in > 10'shff)
        clamp = 8'hff;
    else if (in < 10'sh00)
        clamp = 8'h00;
    else
        clamp = $unsigned(8'(in));
endfunction

always @(posedge CLK) begin
    if (maen)
        mao <= maa + mam1 * mam2;
end

assign co = clamp(10'(mao >>> 10));

always @* begin
    maen = 1;

    case (st)
        3'd1: begin
            maa = y;
            mam1 = v;
            mam2 = V1;
        end
        3'd2: begin
            maa = y;
            mam1 = u;
            mam2 = U1;
        end
        3'd3: begin
            maa = y;
            mam1 = v;
            mam2 = V2;
        end
        3'd4: begin
            maa = mao;
            mam1 = u;
            mam2 = U2;
        end
        default: begin
            maen = 0;
            maa = 0;
            mam1 = 0;
            mam2 = 0;
        end
    endcase
end

always @(posedge CLK) begin
    if (I_PCE) begin
        y <= $signed(20'(I_Y) <<< 10);
        u <= $signed(I_U - 8'd128);
        v <= $signed(I_V - 8'd128);
        vsn <= I_VSn;
        hsn <= I_HSn;
        vbl <= I_VBL;
        hbl <= I_HBL;
        st <= 3'd1;
    end
    else if (st != 0) begin
        st <= st + 1'd1;
    end

    O_PCE <= 0;
    case (st)
        3'd2: r <= co;
        3'd3: b <= co;
        3'd5: begin
            O_PCE <= 1;
            O_R <= r;
            O_G <= co;
            O_B <= b;
            O_VSn <= vsn;
            O_HSn <= hsn;
            O_VBL <= vbl;
            O_HBL <= hbl;
            st <= 0;
        end
        default: ;
    endcase
end

endmodule
