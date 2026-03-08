// KING video testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module huc6272_video_tb;

logic           reset;
logic           clk, ce;
logic           dck, dck_nededge;
logic           hsync_posedge, hsync_negedge;
logic           vsync_posedge, vsync_negedge;
logic [15:0]    ra_di, ra_do;
wire [15:0]     krama_io;
logic [8:0]     ra_a;
logic           ra_oen, ra_rasn, ra_lcasn, ra_ucasn;
logic [15:0]    rb_di, rb_do;
wire [15:0]     kramb_io;
logic [8:0]     rb_a;
logic           rb_oen, rb_rasn, rb_lcasn, rb_ucasn;
logic [23:0]    vd;
logic           vde;

initial begin
    $timeformat(-6, 0, " us", 1);

    $dumpfile("huc6272_video_tb.vcd");
    $dumpvars();
end

huc6272 dut
   (
    .CLK(clk),
    .CE(ce),
    .RESn(~reset),

    .CSn('1),
    .WRn('1),
    .RDn('1),

    .RA_DI(ra_di),
    .RA_DO(ra_do),
    .RA_A(ra_a),
    .RA_OEn(ra_oen),
    .RA_WEn(),
    .RA_RASn(ra_rasn),
    .RA_LCASn(ra_lcasn),
    .RA_UCASn(ra_ucasn),

    .RB_DI(rb_di),
    .RB_DO(rb_do),
    .RB_A(rb_a),
    .RB_OEn(rb_oen),
    .RB_WEn(),
    .RB_RASn(rb_rasn),
    .RB_LCASn(rb_lcasn),
    .RB_UCASn(rb_ucasn),

    .DCK(dck),
    .DCK_NEGEDGE(dck_negedge),
    .HSYNC_POSEDGE(hsync_posedge),
    .HSYNC_NEGEDGE(hsync_negedge),
    .VSYNC_POSEDGE(vsync_posedge),
    .VSYNC_NEGEDGE(vsync_negedge),
    .VD(vd),
    .VDE(vde)
    );

pd424260 krama
   (
    .IO(krama_io),
    .A(ra_a),
    .OEn(ra_oen),
    .WEn('1),
    .RASn(ra_rasn),
    .LCASn(ra_lcasn),
    .UCASn(ra_ucasn)
    );

assign krama_io = ra_oen ? ra_do : 'Z;
assign ra_di = krama_io;

pd424260 kramb
   (
    .IO(kramb_io),
    .A(rb_a),
    .OEn(rb_oen),
    .WEn('1),
    .RASn(rb_rasn),
    .LCASn(rb_lcasn),
    .UCASn(rb_ucasn)
    );

assign kramb_io = rb_oen ? rb_do : 'Z;
assign rb_di = kramb_io;

huc6261 vce
   (
    .CLK(clk),
    .CE(ce),
    .RESn(~reset),

    .CSn('1),
    .WRn('1),
    .RDn('1),
    .A2('0),
    .DI('0),
    .DO(),

    .HSYNC_POSEDGE(hsync_posedge),
    .HSYNC_NEGEDGE(hsync_negedge),
    .VSYNC_POSEDGE(vsync_posedge),
    .VSYNC_NEGEDGE(vsync_negedge),

    .DCKKR(dck),
    .DCKKR_NEGEDGE(dck_negedge),
    .MMC_VD(vd)
    );

initial begin
    reset = 1;
    ce = 0;
    clk = 1;
end

initial forever begin :ckgen
    #0.01 clk = ~clk; // 50 MHz
end

always @(posedge clk) begin :cegen
    ce <= ~ce;
end

//////////////////////////////////////////////////////////////////////

integer fpic;
logic   pice;

initial begin
    fpic = $fopen("huc6272_video_render.hex", "w");
    pice = 0;
end
always @(posedge clk) begin
    if (dck) begin
        if (vde) begin
            $fwrite(fpic, "%x", vd);
            pice = 1;
        end
        else if (pice) begin
            pice = 0;
            $fwrite(fpic, "\n");
        end
    end
end
final
    $fclose(fpic);

//////////////////////////////////////////////////////////////////////

task vram_write(input page, input [17:0] addr, input [15:0] d);
    if (addr[17])
        kramb.write({page, addr[16:9]}, addr[8:0], d);
    else
        krama.write({page, addr[16:9]}, addr[8:0], d);
endtask

task vram_load_file(input string fn, input page);
integer fin;
integer code;
logic [15:0] data;
logic [18:1] addr;
    begin
        fin = $fopen(fn, "rb");
        assert(fin != 0) else $error("Unable to open file %s", fn);
        $display("Loading %s to VRAM page %1d", fn, page);
        addr = 0;
        while (!$feof(fin)) begin :load_loop
            code = $fread(data, fin, 0, 2);
            if (!$feof(fin)) begin
                data = {data[7:0], data[15:8]}; // $fread is big-endian
                vram_write(page, addr, data);
                addr += 1;
            end
        end
        $fclose(fin);
    end
endtask

//////////////////////////////////////////////////////////////////////

initial #0 begin
    vram_load_file("kram0.bin", 0);
    vram_load_file("kram1.bin", 1);

    #10 @(posedge clk) reset <= 0;
    #11 @(posedge clk) ;

    #(17e3) $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s huc6272_video_tb -o huc6272_video_tb.vvp ../huc6272.sv ../huc6272_video.sv ../huc6272_dmc.sv ../huc6261.sv dpram.sv pd424260.sv huc6272_video_tb.sv && ./huc6272_video_tb.vvp && python3 huc6272_render2png.py huc6272_video_render.hex huc6272_video_render.png"
// End:
