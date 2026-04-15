// KING video KRAM read/write testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module huc6272_video_kram_tb;

initial begin
    $timeformat(-6, 0, " us", 1);

    $dumpfile("huc6272_video_kram_tb.vcd");
    $dumpvars();
end

`include "huc6272_dut_kram_vce.svh"

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

task write_verify(input bank, input [17:0] start, input int count);
bit [17:0] addr;
bit [31:0] v, vr;
    reg32_write(7'h0d, {start[17], 3'b0, 10'd1, bank, start[16:0]});
    for (int i = 0; i < count; i+=2) begin
        addr = start + i[17:0];
        v = {~addr[15:0], addr[7:0], addr[15:8]};
        reg32_write(7'h0e, v);
    end
    reg32_write(7'h0c, {start[17], 3'b0, 10'd1, bank, start[16:0]});
    for (int i = 0; i < count; i+=2) begin
        addr = start + i[17:0];
        v = {~addr[15:0], addr[7:0], addr[15:8]};
        reg32_read(7'h0e, vr);
        assert(v === vr);
    end
endtask

initial #0 begin
    #10 @(posedge clk) reset <= 0;
    #2 @(posedge clk) ;

    load_kreg();

    write_verify(1'b0, 18'h00000, 32);
    write_verify(1'b0, 18'h3FFE0, 32);
    write_verify(1'b1, 18'h00000, 32);
    write_verify(1'b1, 18'h3FFE0, 32);

    @(posedge dut.video.render) ;
    write_verify(1'b0, 18'h00000, 32);
    @(posedge dut.video.render) ;
    write_verify(1'b1, 18'h00000, 32);

    #(1e3) $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s huc6272_video_kram_tb -DHUC6272_DMC_ENABLE -o huc6272_video_kram_tb.vvp ../huc6272.sv ../huc6261.sv dpram.sv pd424260.sv huc6272_video_kram_tb.sv && ./huc6272_video_kram_tb.vvp"
// End:
