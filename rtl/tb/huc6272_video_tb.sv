// KING video testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module huc6272_video_tb;

logic           reset;
logic           clk, ce;
logic [2:1]     a;
logic           csn, rdn, wrn;
logic [15:0]    din, dout;
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

    .A(a),
    .DI(din),
    .DO(dout),
    .CSn(csn),
    .WRn(wrn),
    .RDn(rdn),

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
    rdn = 1;
    wrn = 1;
    csn = 1;
    clk = 1;
end

initial forever begin :ckgen
    #0.01 clk = ~clk; // 50 MHz
end

always @(posedge clk) begin :cegen
    ce <= ~ce;
end

//////////////////////////////////////////////////////////////////////

task io_write16(input [2:1] ain, input [15:0] v);
    @(posedge clk) ;
    while (!ce)
        @(posedge clk) ;
    a <= ain;
    din <= v;
    wrn <= 0;
    csn <= 0;

    @(posedge clk) ;
    while (!ce)
        @(posedge clk) ;
    din <= 'X;
    wrn <= 1;
    csn <= 1;
endtask

task reg_write(input [6:0] rs, input [15:0] v);
    io_write16(2'b00, 16'(rs));
    io_write16(2'b10, v);
endtask

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

task load_kreg();
    // KING BG
    reg_write(7'h10, 16'h0005); // Mode
    reg_write(7'h12, 16'h0004); // Prio
    reg_write(7'h16, 16'h0001); // ScrM
    // KBG0
    reg_write(7'h2c, 16'h8888); // Size
    reg_write(7'h20, 16'h0000); // BAT
    reg_write(7'h21, 16'h0080); // CG
    reg_write(7'h22, 16'h0000); // SubBAT
    reg_write(7'h23, 16'h0080); // SubCG
    reg_write(7'h30, 16'h0000); // XScr
    reg_write(7'h31, 16'h0000); // YScr
    // KBG1
    reg_write(7'h2d, 16'h0000); // Size
    reg_write(7'h24, 16'h0000); // BAT
    reg_write(7'h25, 16'h0000); // CG
    reg_write(7'h32, 16'h0000); // XScr
    reg_write(7'h33, 16'h0000); // YScr
    // KBG2
    reg_write(7'h2e, 16'h0000); // Size
    reg_write(7'h28, 16'h0000); // BAT
    reg_write(7'h29, 16'h0000); // CG
    reg_write(7'h34, 16'h0000); // XScr
    reg_write(7'h35, 16'h0000); // YScr
    // KBG3
    reg_write(7'h2f, 16'h0000); // Size
    reg_write(7'h2a, 16'h0000); // BAT
    reg_write(7'h2b, 16'h0000); // CG
    reg_write(7'h34, 16'h0000); // XScr
    reg_write(7'h35, 16'h0000); // YScr
    // AFFIN
    reg_write(7'h38, 16'h0000); // A
    reg_write(7'h39, 16'h0000); // B
    reg_write(7'h3a, 16'h0000); // C
    reg_write(7'h3b, 16'h0000); // D
    reg_write(7'h3c, 16'h0000); // X
    reg_write(7'h3d, 16'h0000); // Y
    // MPROG
    reg_write(7'h13, 16'h0000); // uAddr=0
    reg_write(7'h14, 16'h0100); // 0
    reg_write(7'h14, 16'h0100); // 1
    reg_write(7'h14, 16'h0100); // 2
    reg_write(7'h14, 16'h0100); // 3
    reg_write(7'h14, 16'h0100); // 4
    reg_write(7'h14, 16'h0100); // 5
    reg_write(7'h14, 16'h0100); // 6
    reg_write(7'h14, 16'h0100); // 7
    reg_write(7'h14, 16'h0000); // 8
    reg_write(7'h14, 16'h0001); // 9
    reg_write(7'h14, 16'h0002); // A
    reg_write(7'h14, 16'h0003); // B
    reg_write(7'h14, 16'h0004); // C
    reg_write(7'h14, 16'h0005); // D
    reg_write(7'h14, 16'h0006); // E
    reg_write(7'h14, 16'h0007); // F
    reg_write(7'h15, 16'h0001); // MPSW=1
endtask

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
    #2 @(posedge clk) ;

    load_kreg();

    #(1e3) $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s huc6272_video_tb -o huc6272_video_tb.vvp ../huc6272.sv ../huc6261.sv dpram.sv pd424260.sv huc6272_video_tb.sv && ./huc6272_video_tb.vvp && python3 huc6272_render2png.py huc6272_video_render.hex huc6272_video_render.png"
// End:
