// NEW Iron Guanyin video render testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module huc6261_video_render_tb;

initial begin
    $timeformat(-6, 0, " us", 1);

    $dumpfile("huc6261_video_render_tb.vcd");
    $dumpvars();
end

`include "mmc_kram_vce.svh"

//////////////////////////////////////////////////////////////////////

integer fpic;
logic   pice;

initial begin
    fpic = $fopen("huc6261_video_render.hex", "w");
    pice = 0;
end
always @(posedge clk) begin
    if (dck) begin
        if (vce_vde) begin
            $fwrite(fpic, "%x", vce_vd);
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

task load_vce_reg();
    io_sel = VCE;
    reg_write(7'h00, 16'h0700); // CR
    reg_write(7'h04, 16'h0800); // CPAO1
    reg_write(7'h08, 16'h4567); // PR1
    reg_write(7'h09, 16'h0123); // PR2

    // Palette
    //reg_write(7'h01, 16'h0000); // addr = 0
    //reg_write(7'h02, 16'h0000); // ent[0]
endtask

task load_vdc0_reg();
    io_sel = VDC0;
    reg_write(7'h05, 16'h00c8); // CR
    reg_write(7'h06, 16'h0000); // RCR
    reg_write(7'h07, 16'h0000); // BXR
    reg_write(7'h08, 16'h0000); // BYR
    reg_write(7'h09, 16'h0050); // MWR
    reg_write(7'h0a, 16'h0202); // HSR
    reg_write(7'h0b, 16'h041f); // HDR
    reg_write(7'h0c, 16'h1102); // VPR
    reg_write(7'h0d, 16'h00ef); // VDR
    reg_write(7'h0e, 16'h0002); // VCR
    reg_write(7'h13, 16'h7f00); // DVSSR
endtask

task load_vdc1_reg();
    io_sel = VDC1;
    reg_write(7'h05, 16'h00c0); // CR
    reg_write(7'h06, 16'h0000); // RCR
    reg_write(7'h07, 16'h0000); // BXR
    reg_write(7'h08, 16'hfff8); // BYR
    reg_write(7'h09, 16'h0050); // MWR
    reg_write(7'h0a, 16'h0202); // HSR
    reg_write(7'h0b, 16'h041f); // HDR
    reg_write(7'h0c, 16'h1102); // VPR
    reg_write(7'h0d, 16'h00ef); // VDR
    reg_write(7'h0e, 16'h0002); // VCR
    reg_write(7'h13, 16'h7f00); // DVSSR
endtask

task load_kreg();
    // KING BG
    io_sel = MMC;
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

initial #0 begin
    $readmemh("vram0.hex", vram0.mem);
    $readmemh("vram1.hex", vram1.mem);
    $readmemh("vce_cp.hex", vce.cpram.mem);
    vram_load_file("kram0.bin", 0);
    vram_load_file("kram1.bin", 1);

    #10 @(posedge clk) reset <= 0;
    #2 @(posedge clk) ;

    load_vce_reg();
    load_vdc0_reg();
    load_vdc1_reg();
    load_kreg();

    // Advance a frame to trigger V-Blank actions like SATB copy.
    @(posedge vsync_negedge) ;
    repeat (2) @(posedge hsync_negedge) ;
    vdc0.DISP_CNT = 10'h014;
    vdc1.DISP_CNT = 10'h014;
    repeat (2) @(posedge hsync_negedge) ;
    vdc0.DISP_CNT = 10'h104;
    vdc1.DISP_CNT = 10'h104;
    vce.v_cnt = 9'h106;
    mmc.video.row = 10'h103;
    @(posedge hsync_negedge) ;

    #(15e3) $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s huc6261_video_render_tb -DHUC6272_DMC_ENABLE -DTB_VDC -o huc6261_video_render_tb.vvp ../huc6272.sv ../huc6261.sv ../huc6270.sv dpram.sv pd424260.sv huc6261_video_render_tb.sv && ./huc6261_video_render_tb.vvp && python3 yuv_render2png.py huc6261_video_render.hex huc6261_video_render.png 270 242"
// End:
